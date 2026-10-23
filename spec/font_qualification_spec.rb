# frozen_string_literal: true

require "spec_helper"
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
end
