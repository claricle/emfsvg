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

  it "rejects an installer checksum before invoking extraction and removes partial staging" do
    allow(extractor).to receive(:call)
    bad = described_class.new(options, downloader: ->(_url, path) { File.write(path, "wrong") }, extractor: extractor)
    expect { bad.provision }.to raise_error(/SHA256 mismatch/)
    expect(extractor).not_to have_received(:call)
    expect(Dir.glob(File.join(@directory, "corefonts-*"))).to be_empty
    expect(File.exist?(options.fetch("contract_path"))).to be(false)
  end

  it "reports download failures without publishing a contract" do
    bad = described_class.new(options, downloader: ->(*) { raise IOError, "network unavailable" }, extractor: extractor)
    expect { bad.provision }.to raise_error(IOError, "network unavailable")
    expect(File.exist?(options.fetch("contract_path"))).to be(false)
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

  it "reports an unsuccessful archive extraction" do
    status = instance_double(Process::Status, success?: false)
    allow(Open3).to receive(:capture3).and_return(["", "unsupported archive", status])
    expect { provisioner.send(:extract, "7zz", "installer.exe", "Arial.TTF", "unused") }
      .to raise_error(/Extraction failed for Arial.TTF: unsupported archive/)
  end

  it "rejects empty archive output without writing a font" do
    status = instance_double(Process::Status, success?: true)
    allow(Open3).to receive(:capture3).and_return(["", "", status])
    destination = File.join(@directory, "Arial.TTF")
    expect { provisioner.send(:extract, "7zz", "installer.exe", "Arial.TTF", destination) }
      .to raise_error(/Missing font entry: Arial.TTF/)
    expect(File.exist?(destination)).to be(false)
  end

  it "streams only pinned archive entries to controlled paths" do
    status = instance_double(Process::Status, success?: true)
    allow(Open3).to receive(:capture3).and_return(["font", "", status])
    provisioner.send(:extract, "7zz", "installer.exe", "Arial.TTF", File.join(@directory, "Arial.TTF"))
    expect(Open3).to have_received(:capture3).with("7zz", "e", "-so", "installer.exe", "Arial.TTF", binmode: true)
    expect(Dir.children(@directory).sort).to eq(["Arial.TTF", "reference"])
  end
end
