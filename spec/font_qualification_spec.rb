# frozen_string_literal: true

require "spec_helper"
require "fontisan"
require "rbconfig"
require_relative "../scripts/support/font_qualification"

RSpec.describe FontQualification do
  include Emfsvg::SpecSupport::FontQualificationFixture

  around do |example|
    Dir.mktmpdir("font-qualification") do |directory|
      @directory = directory
      @contract = qualification_contract(directory)
      example.run
    end
  end

  let(:qualifier) { described_class.new(@contract) }

  it "rejects a changed font before running any resolver or native command" do
    File.binwrite(@contract.fetch("fonts").fetch("arial_regular").fetch("path"), "different font")
    expect { qualifier }.to raise_error(/File checksum mismatch/)
  end

  it "requires an explicit license provenance statement" do
    @contract.fetch("fonts").fetch("verdana_bold")["license_provenance"] = " "
    expect { qualifier }.to raise_error(/Missing license provenance for verdana_bold/)
  end

  it "isolates the inventory and applies David fallback only in its generated configuration" do
    extra = File.join(@directory, "unqualified.ttf")
    File.write(extra, "unqualified")
    previous = ENV.fetch("FONTCONFIG_FILE", nil)
    configuration = qualifier.configuration(File.join(@directory, "cache"))
    document = REXML::Document.new(configuration)
    expect(REXML::XPath.match(document, "//include")).to be_empty
    expect(REXML::XPath.match(document, "//rejectfont/glob").map(&:text)).to eq([File.realpath(extra)])
    expect(REXML::XPath.first(document, "//test[@name='family']/string").text).to eq("David")
    expect(REXML::XPath.first(document, "//edit[@name='family']/string").text).to eq("Verdana")
    expect(ENV.fetch("FONTCONFIG_FILE", nil)).to eq(previous)
  end

  it "attests actual file and cmap bytes including intentionally absent glyph155" do
    font = @contract.fetch("fonts").fetch("verdana_regular")
    result = qualifier.attest_font("verdana_regular", "David", "David", font.fetch("path"))
    expect(result.fetch("sha256")).to eq(font.fetch("sha256"))
    expect(result.fetch("cmap_sha256")).to eq(font.fetch("cmap_sha256"))
    expect(result.fetch("required_mappings").fetch(155)).to be_nil
    expect(result.fetch("bytes")).to eq(File.size(font.fetch("path")))
  end

  it "reads cmap mappings through Fontisan's public API" do
    font = @contract.fetch("fonts").fetch("verdana_regular")
    cmap = File.binread(font.fetch("path")).byteslice(28..)
    mapper = Emfsvg::GlyphIndexMapper.new
    allow(Emfsvg::GlyphIndexMapper).to receive(:new).and_return(mapper)
    allow(Fontisan::Tables::Cmap).to receive(:read).and_call_original
    expect(mapper).not_to receive(:parse_cmap_reverse)

    qualifier.attest_font("verdana_regular", "David", "David", font.fetch("path"))

    expect(Fontisan::Tables::Cmap).to have_received(:read).with(cmap)
  end

  it "keeps the last codepoint when reversing duplicate glyph mappings" do
    font = @contract.fetch("fonts").fetch("verdana_regular")
    mappings = FontQualification::REQUIRED.fetch("David").compact.invert
    mappings[0x002E] = 15
    cmap = Struct.new(:unicode_mappings).new(mappings)
    allow(Fontisan::Tables::Cmap).to receive(:read).and_return(cmap)

    expect { qualifier.attest_font("verdana_regular", "David", "David", font.fetch("path")) }
      .to(raise_error { |error| expect(error.message).to match(/\b15\s*=>\s*44\b/) })
  end

  it "rejects a matching file hash whose required cmap mapping is incompatible" do
    font = qualification_font(File.join(@directory, "wrong.ttf"), { 675 => 0x0041 })
    @contract.fetch("fonts")["arial_regular"] = font
    expect { qualifier.attest_font("arial_regular", "Arial", "Arial", font.fetch("path")) }
      .to raise_error(/Incompatible glyph mappings/)
  end

  it "rejects a changed cmap checksum even when the whole-file checksum matches" do
    font = @contract.fetch("fonts").fetch("arial_regular")
    font["cmap_sha256"] = "0" * 64
    expect { qualifier.attest_font("arial_regular", "Arial", "Arial", font.fetch("path")) }
      .to raise_error(/cmap checksum mismatch/)
  end

  it "exercises public Ruby vectors through parsed cmaps, preserving RTL and missing glyph truncation" do
    mapper = Emfsvg::GlyphIndexMapper.new
    allow(Emfsvg::GlyphIndexMapper).to receive(:new).and_return(mapper)
    allow(mapper).to receive(:find_font_path) do |family, _weight, _italic|
      role = family == "Arial" ? "arial_regular" : "verdana_regular"
      @contract.fetch("fonts").fetch(role).fetch("path")
    end
    expect(qualifier.ruby_vectors.map { |vector| vector.fetch("output") }).to eq(["אבגד", "“ƒΩ≈", "", "", ","])
  end

  it "rejects inventory contamination before attesting resolver candidates" do
    paths = @contract.fetch("fonts").values.map { |font| font.fetch("path") }
    extra = File.join(@directory, "extra.ttf")
    File.write(extra, "extra")
    inventory = (paths + [extra]).join("\n")
    format = described_class::FONTCONFIG_FORMAT
    allow(qualifier).to receive(:capture).with("fc-list", "-f", format).and_return(inventory)
    expect { qualifier.attest_fonts }.to raise_error(/inventory differs/)
  end

  it "removes a stale success report when an input fails validation" do
    @contract["output_directory"] = @directory
    report = File.join(@directory, "qualification.json")
    File.write(report, "previous success")
    @contract.fetch("fonts").fetch("arial_regular")["sha256"] = "0" * 64
    contract_path = File.join(@directory, "contract.json")
    File.write(contract_path, JSON.generate(@contract))
    script = File.expand_path("../scripts/qualify_fonts.rb", __dir__)
    _stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, contract_path)
    expect(status.exitstatus).to eq(1)
    expect(stderr).to include("File checksum mismatch")
    expect(File.exist?(report)).to be(false)
  end

  it "qualifies all four fonts and five Ruby vectors in a fresh child without C inputs" do
    stdout, stderr, status = qualification_cli(@contract, @directory, "--ruby-only")
    expect(status.exitstatus).to eq(0), stderr
    result = JSON.parse(stdout)
    expect(result.fetch("mode")).to eq("ruby_only")
    expect(result.fetch("scope")).to start_with("Ruby glyph vectors only")
    expect(result.fetch("c_reference")).to include("status" => "not_run")
    expect(result.fetch("fonts").map { |font| font.fetch("role") }).to eq(described_class::ROLES)
    expect(result.fetch("fonts").map { |font| font.fetch("sha256") })
      .to eq(@contract.fetch("fonts").values.map { |font| font.fetch("sha256") })
    expect(result.fetch("ruby_vectors").map { |vector| vector.fetch("output") }).to eq(["אבגד", "“ƒΩ≈", "", "", ","])
    expect(JSON.parse(File.read(File.join(@directory, "qualification.json")))).to eq(result)
    argv = File.readlines(File.join(@directory, "commands", "fc-match-argv.log"), chomp: true).map do |line|
      JSON.parse(line)
    end.first(4)
    format_argument = described_class::FONTCONFIG_FORMAT
    expect(argv).to eq(
      [["-f", format_argument, "Arial"], ["-f", format_argument, "Arial:weight=bold"],
       ["-f", format_argument, "David"], ["-f", format_argument, "David:weight=bold"]]
    )
  end

  it "selects the requested family when a command wrapper appends an argument" do
    fonts = @contract.fetch("fonts").transform_values { |font| font.fetch("path") }
    resolver = File.join(@directory, "fc-match")
    File.write(resolver, qualification_resolver(fonts))
    configuration = File.join(@directory, "fonts.conf")
    File.write(configuration, "isolated configuration")

    stdout, stderr, status = Open3.capture3({ "FONTCONFIG_FILE" => configuration }, RbConfig.ruby, resolver,
                                            "-f", "format", "Arial", "")

    expect(status.exitstatus).to eq(0), stderr
    expect(stdout.strip).to eq(@contract.fetch("fonts").fetch("arial_regular").fetch("path"))
  end

  it "preserves the resolver family across Windows batch argument forwarding" do
    fonts = @contract.fetch("fonts").transform_values { |font| font.fetch("path") }
    resolver = File.join(@directory, "fc-match")
    File.write(resolver, qualification_resolver(fonts))
    configuration = File.join(@directory, "fonts.conf")
    File.write(configuration, "isolated configuration")

    stdout, stderr, status = Open3.capture3(
      { "FONTCONFIG_FILE" => configuration, "FONTCONFIG_BATCH_SIMULATION" => "1" },
      RbConfig.ruby, resolver, "-f", described_class::FONTCONFIG_FORMAT, "Arial"
    )

    expect(status.exitstatus).to eq(0), stderr
    expect(stdout.strip).to eq(@contract.fetch("fonts").fetch("arial_regular").fetch("path"))
    expect(JSON.parse(File.read(File.join(@directory, "fc-match-argv.log"))))
      .to eq(["-f", described_class::FONTCONFIG_FORMAT, "Arial"])
  end

  it "reports unexpected resolver arguments instead of silently choosing Verdana" do
    fonts = @contract.fetch("fonts").transform_values { |font| font.fetch("path") }
    resolver = File.join(@directory, "fc-match")
    File.write(resolver, qualification_resolver(fonts))
    configuration = File.join(@directory, "fonts.conf")
    File.write(configuration, "isolated configuration")

    _stdout, stderr, status = Open3.capture3({ "FONTCONFIG_FILE" => configuration }, RbConfig.ruby, resolver,
                                             "-f", "format", "unrecognized-family")

    expect(status.exitstatus).to eq(1)
    expect(stderr).to include('Unexpected fc-match argv: ["-f", "format", "unrecognized-family"]')
    expect(File.read(File.join(@directory, "fc-match-argv.log"))).to eq("[\"-f\",\"format\",\"unrecognized-family\"]\n")
  end

  it "keeps the default pinned C hash check and removes stale reports on native failure" do
    native = File.join(@directory, "unqualified-reference")
    File.write(native, "a different native binary")
    @contract["c_reference"] = { "binary" => native, "library" => native }
    report = File.join(@directory, "qualification.json")
    File.write(report, "previous success")
    _stdout, stderr, status = qualification_cli(@contract, @directory)
    expect(status.exitstatus).to eq(1)
    expect(stderr).to include("File checksum mismatch for #{native}")
    expect(File.exist?(report)).to be(false)
  end

  it "removes a stale Ruby-only report when cmap validation fails" do
    report = File.join(@directory, "qualification.json")
    File.write(report, "previous success")
    @contract.fetch("fonts").fetch("verdana_bold")["cmap_sha256"] = "0" * 64
    _stdout, stderr, status = qualification_cli(@contract, @directory, "--ruby-only")
    expect(status.exitstatus).to eq(1)
    expect(stderr).to include("cmap checksum mismatch for verdana_bold")
    expect(File.exist?(report)).to be(false)
  end

  it "runs the native vectors in the default report mode" do
    configuration = File.join(@directory, "fonts.conf")
    File.write(configuration, qualifier.configuration(File.join(@directory, "cache")))
    allow(ENV).to receive(:fetch).with("FONTCONFIG_FILE").and_return(configuration)
    allow(qualifier).to receive_messages(attest_fonts: [], ruby_vectors: [])
    expect(qualifier).to receive(:native_vectors).and_return({ "fixtures" => [183, 185] })
    result = qualifier.probe
    expect(result.fetch("mode")).to eq("full")
    expect(result.fetch("scope")).to start_with("Ruby and pinned C glyph vectors only")
    expect(result.fetch("c_reference")).to eq("fixtures" => [183, 185])
  end

  it "rejects unknown CLI options" do
    _stdout, stderr, status = qualification_cli(@contract, @directory, "--ruby-onyl")
    expect(status.exitstatus).to eq(1)
    expect(stderr).to include("invalid option: --ruby-onyl")
    expect(File.exist?(File.join(@directory, "qualification.json"))).to be(false)
  end

  it "rejects extra CLI arguments" do
    _stdout, stderr, status = qualification_cli(@contract, @directory, "unexpected")
    expect(status.exitstatus).to eq(1)
    expect(stderr).to include("Expected one contract path")
    expect(File.exist?(File.join(@directory, "qualification.json"))).to be(false)
  end
end
