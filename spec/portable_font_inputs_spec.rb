# frozen_string_literal: true

require "spec_helper"
require_relative "../scripts/support/portable_font_inputs"

RSpec.describe PortableFontInputs do
  around do |example|
    Dir.mktmpdir("portable-font-inputs") do |directory|
      @directory = directory
      example.run
    end
  end

  let(:options) do
    reference = File.join(@directory, "reference")
    File.write(reference, "reference")
    { "staging_directory" => @directory, "corpus_root" => @directory,
      "output_directory" => File.join(@directory, "output"), "contract_path" => File.join(@directory, "contract.json"),
      "c_reference" => { "binary" => reference, "library" => reference } }
  end
  let(:downloader) { ->(_url, path) { File.binwrite(path, "installer") } }
  let(:extractor) { ->(_archive, _entry, path) { File.binwrite(path, "font") } }
  let(:provisioner) { described_class.new(options, downloader: downloader, extractor: extractor) }

  before do
    installers = described_class::INSTALLERS.transform_values { Digest::SHA256.hexdigest("installer") }
    fonts = described_class::FONTS.transform_values do |installer, entry, _sha, cmap|
      [installer, entry, Digest::SHA256.hexdigest("font"), cmap]
    end
    stub_const("PortableFontInputs::INSTALLERS", installers)
    stub_const("PortableFontInputs::FONTS", fonts)
  end

  it "emits four pinned files and preserves caller paths in the existing contract shape" do
    contract = provisioner.provision
    expect(JSON.parse(File.read(options.fetch("contract_path")))).to eq(contract)
    expect(contract.slice("corpus_root", "output_directory", "c_reference"))
      .to eq(options.slice("corpus_root", "output_directory", "c_reference"))
    expect(contract.fetch("fonts").keys).to eq(%w[arial_regular arial_bold verdana_regular verdana_bold])
    expect(contract.fetch("fonts").values).to all(include("sha256" => Digest::SHA256.hexdigest("font")))
    expect(contract.fetch("fonts").values.map { |font| File.binread(font.fetch("path")) }).to eq(["font"] * 4)
    expect(contract.fetch("fonts").values.map { |font| font.fetch("license_provenance") }).to all(include("EULA"))
  end

  it "provisions fonts without a C reference and omits it from the contract" do
    options.delete("c_reference")

    contract = provisioner.provision

    expect(JSON.parse(File.read(options.fetch("contract_path")))).to eq(contract)
    expect(contract).not_to have_key("c_reference")
    expect(contract.fetch("fonts").keys).to eq(%w[arial_regular arial_bold verdana_regular verdana_bold])
  end

  it "retries a transient transport timeout and completes provisioning" do
    attempts = 0
    retrying_downloader = lambda do |_url, path|
      attempts += 1
      raise Net::OpenTimeout, "temporary connection timeout" if attempts == 1

      File.binwrite(path, "installer")
    end
    retrying = described_class.new(options, downloader: retrying_downloader, extractor: extractor)

    contract = retrying.provision

    expect(attempts).to eq(3)
    expect(contract.fetch("fonts").keys).to eq(%w[arial_regular arial_bold verdana_regular verdana_bold])
    expect(File).to exist(options.fetch("contract_path"))
  end

  it "stops after three transient timeouts and removes partial staging" do
    attempts = 0
    timeout_downloader = lambda do |_url, path|
      attempts += 1
      File.binwrite(path, "partial installer")
      raise Net::OpenTimeout, "connection timeout"
    end
    retrying = described_class.new(
      options,
      downloader: timeout_downloader,
      extractor: extractor
    )

    expect { retrying.provision }.to raise_error(Net::OpenTimeout, "connection timeout")
    expect(attempts).to eq(3)
    expect(Dir.glob(File.join(@directory, "corefonts-*"))).to be_empty
    expect(File).not_to exist(options.fetch("contract_path"))
  end

  it "rejects an installer checksum before invoking extraction and removes partial staging" do
    allow(extractor).to receive(:call)
    attempts = 0
    bad_downloader = lambda do |_url, path|
      attempts += 1
      File.write(path, "wrong")
    end
    bad = described_class.new(options, downloader: bad_downloader, extractor: extractor)
    expect { bad.provision }.to raise_error(/SHA256 mismatch/)
    expect(attempts).to eq(1)
    expect(extractor).not_to have_received(:call)
    expect(Dir.glob(File.join(@directory, "corefonts-*"))).to be_empty
    expect(File.exist?(options.fetch("contract_path"))).to be(false)
  end

  it "reports download failures without publishing a contract" do
    attempts = 0
    failure_downloader = lambda do |*|
      attempts += 1
      raise IOError, "network unavailable"
    end
    bad = described_class.new(options, downloader: failure_downloader, extractor: extractor)
    expect { bad.provision }.to raise_error(IOError, "network unavailable")
    expect(attempts).to eq(1)
    expect(File.exist?(options.fetch("contract_path"))).to be(false)
    expect(Dir.glob(File.join(@directory, "corefonts-*"))).to be_empty
  end

  it "rejects a missing extraction tool before downloading" do
    allow(ENV).to receive(:fetch).with("PATH", "").and_return(@directory)
    allow(downloader).to receive(:call)
    bad = described_class.new(options, downloader: downloader)
    expect { bad.provision }.to raise_error(/Missing extractor/)
    expect(downloader).not_to have_received(:call)
  end

  it "rejects a missing extracted font" do
    bad = described_class.new(options, downloader: downloader, extractor: ->(*) {})
    expect { bad.provision }.to raise_error(/Missing input file/)
    expect(File.exist?(options.fetch("contract_path"))).to be(false)
  end

  it "rejects a wrong extracted font checksum" do
    wrong_font = ->(_archive, _entry, path) { File.write(path, "wrong") }
    bad = described_class.new(options, downloader: downloader, extractor: wrong_font)
    expect { bad.provision }.to raise_error(/SHA256 mismatch/)
  end

  it "uses locally cached intact installers without downloading" do
    cache = File.join(@directory, "installers")
    Dir.mkdir(cache)
    described_class::INSTALLERS.each_key { |name| File.write(File.join(cache, name), "installer") }
    options["installers_directory"] = cache
    allow(downloader).to receive(:call)
    provisioner.provision
    expect(downloader).not_to have_received(:call)
    expect(Dir.children(cache).sort).to eq(%w[arial32.exe verdan32.exe])
  end

  it "rejects relative output paths before downloading" do
    options["output_directory"] = "relative"
    expect { provisioner.provision }.to raise_error(/absolute path for output_directory/)
  end

  it "rejects missing reference files" do
    options.fetch("c_reference")["library"] = File.join(@directory, "missing")
    expect { provisioner.provision }.to raise_error(/Missing reference library/)
  end

  it "rejects relative supplied reference paths" do
    options.fetch("c_reference")["binary"] = "relative"
    expect { provisioner.provision }.to raise_error(/absolute path for c_reference.binary/)
  end

  it "rejects missing corpus directories" do
    options["corpus_root"] = File.join(@directory, "missing")
    expect { provisioner.provision }.to raise_error(/Missing directory for corpus_root/)
  end

  it "rejects contract paths without an existing parent" do
    options["contract_path"] = File.join(@directory, "missing", "contract.json")
    expect { provisioner.provision }.to raise_error(/Missing contract parent/)
  end

  it "preserves an existing contract and unrelated files" do
    File.write(options.fetch("contract_path"), "prior evidence")
    extra = File.join(@directory, "unrelated")
    File.write(extra, "preserved")
    expect { provisioner.provision }.to raise_error(/Contract path already exists/)
    expect(File.read(options.fetch("contract_path"))).to eq("prior evidence")
    expect(File.read(extra)).to eq("preserved")
  end

  context "with the discovered archive extractor" do
    let(:archive_provisioner) { described_class.new(options, downloader: downloader) }
    let(:tool) { File.join(@directory, "7zz.exe") }

    before do
      File.write(tool, "")
      File.chmod(0o755, tool)
      allow(ENV).to receive(:fetch).with("PATH", "").and_return(@directory)
    end

    it "reports an unsuccessful archive extraction" do
      status = Open3.capture3(RbConfig.ruby, "-e", "exit 1").last
      allow(Open3).to receive(:capture3).and_return(["", "unsupported archive", status])

      expect { archive_provisioner.provision }
        .to raise_error(/Extraction failed for Arial.TTF: unsupported archive/)
      expect(Dir.glob(File.join(@directory, "corefonts-*"))).to be_empty
      expect(File).not_to exist(options.fetch("contract_path"))
    end

    it "rejects empty archive output without writing a font" do
      status = Open3.capture3(RbConfig.ruby, "-e", "exit 0").last
      allow(Open3).to receive(:capture3).and_return(["", "", status])

      expect { archive_provisioner.provision }.to raise_error(/Missing font entry: Arial.TTF/)
      expect(Dir.glob(File.join(@directory, "**", "Arial.TTF"))).to be_empty
      expect(Dir.glob(File.join(@directory, "corefonts-*"))).to be_empty
      expect(File).not_to exist(options.fetch("contract_path"))
    end

    it "streams only pinned archive entries to controlled paths" do
      status = Open3.capture3(RbConfig.ruby, "-e", "exit 0").last
      allow(Open3).to receive(:capture3).and_return(["font", "", status])

      contract = archive_provisioner.provision
      fonts = contract.fetch("fonts")
      directory = File.dirname(fonts.fetch("arial_regular").fetch("path"), 2)

      described_class::FONTS.each do |role, (installer, entry, _sha, _cmap)|
        expect(Open3).to have_received(:capture3)
          .with(tool, "e", "-so", File.join(directory, installer), entry, binmode: true).once
        expect(fonts.fetch(role).fetch("path")).to eq(File.join(directory, "fonts", entry))
        expect(File.binread(fonts.fetch(role).fetch("path"))).to eq("font")
      end
      expect(Open3).to have_received(:capture3).exactly(4).times
      expect(Dir.children(File.join(directory, "fonts")).sort)
        .to eq(described_class::FONTS.values.map { |_installer, entry, _sha, _cmap| entry }.sort)
      expect(Dir.children(directory).sort).to eq(%w[arial32.exe fonts verdan32.exe])
      expect(Dir.children(@directory).sort)
        .to eq(["7zz.exe", File.basename(directory), "contract.json", "reference"].sort)
      expect(JSON.parse(File.read(options.fetch("contract_path")))).to eq(contract)
    end
  end
end
