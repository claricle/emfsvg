# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Emfsvg::Compat do
  include Emfsvg::SpecSupport::CompatReferenceFixture

  let(:reference_mode) { "success" }
  let(:binary) { File.join(@reference_directory, windows_reference? ? "reference.cmd" : "reference") }
  let(:input_path) { File.join(@reference_directory, "input.emf") }
  let(:output_path) { File.join(@reference_directory, "saved.svg") }

  around do |example|
    previous = ENV.to_h.slice("EMF2SVG_REF_PATH", "EMF2SVG_REF_LIB_DIR")
    Dir.mktmpdir("emfsvg reference spec ") do |directory|
      @reference_directory = directory
      ENV["EMF2SVG_REF_PATH"] = binary
      ENV["EMF2SVG_REF_LIB_DIR"] = directory
      File.write(binary, compat_reference_wrapper(reference_mode))
      File.chmod(0o755, binary) unless windows_reference?
      example.run
    end
  ensure
    ENV.delete("EMF2SVG_REF_PATH")
    ENV.delete("EMF2SVG_REF_LIB_DIR")
    ENV.update(previous)
  end

  it "requires an explicit reference executable" do
    ENV.delete("EMF2SVG_REF_PATH")

    expect { described_class.generate_reference(input_path) }
      .to raise_error(described_class::SetupError, /EMF2SVG_REF_PATH.*README/)
    expect(described_class.ref_binary_available?).to be(false)
  end

  it "rejects a non-executable reference file" do
    non_executable = File.join(@reference_directory, "reference.txt")
    File.write(non_executable, "not executable")
    File.chmod(0o644, non_executable)
    ENV["EMF2SVG_REF_PATH"] = non_executable
    expect(File.executable?(non_executable)).to be(false)

    expect { described_class.validate_reference! }
      .to raise_error(described_class::SetupError, /EMF2SVG_REF_PATH/)
  end

  it "rejects a directory in place of an executable" do
    ENV["EMF2SVG_REF_PATH"] = @reference_directory

    expect { described_class.validate_reference! }
      .to raise_error(described_class::SetupError, /EMF2SVG_REF_PATH/)
  end

  it "requires an explicit library directory" do
    ENV.delete("EMF2SVG_REF_LIB_DIR")

    expect { described_class.generate_reference(input_path) }
      .to raise_error(described_class::SetupError, /EMF2SVG_REF_LIB_DIR.*README/)
  end

  it "rejects a file in place of the library directory" do
    ENV["EMF2SVG_REF_LIB_DIR"] = binary

    expect { described_class.validate_reference! }
      .to raise_error(described_class::SetupError, /EMF2SVG_REF_LIB_DIR/)
  end

  it "returns reference bytes and removes its temporary directory" do
    expect(described_class.ref_binary_available?).to be(true)
    expect(described_class.generate_reference(input_path)).to eq("<svg/>")
    expect(File.exist?(File.dirname(File.read(input_path)))).to be(false)
  end

  it "retains the explicitly requested output" do
    expect(described_class.generate_reference(input_path, output_path)).to eq("<svg/>")
    expect(File.binread(output_path)).to eq("<svg/>")
    expect(File.exist?(File.dirname(File.read(input_path)))).to be(false)
  end

  context "when the reference conversion fails" do
    let(:reference_mode) { "failure" }

    it "reports the failure and cleans temporary output without replacing existing output" do
      File.write(output_path, "existing reference")

      expect { described_class.generate_reference(input_path, output_path) }
        .to raise_error(described_class::ConversionError, /input.emf.*exit 7.*invalid EMF/)
      expect(File.binread(output_path)).to eq("existing reference")
      expect(File.exist?(File.dirname(File.read(input_path)))).to be(false)
    end
  end

  context "when the reference writes no output" do
    let(:reference_mode) { "missing" }

    it "reports the missing output and cleans its temporary directory" do
      expect { described_class.generate_reference(input_path) }
        .to raise_error(described_class::ConversionError, /produced no SVG/)
      expect(File.exist?(File.dirname(File.read(input_path)))).to be(false)
    end
  end

  context "when the reference writes an empty output" do
    let(:reference_mode) { "empty" }

    it "rejects the empty SVG and cleans its temporary directory" do
      expect { described_class.generate_reference(input_path) }
        .to raise_error(described_class::ConversionError, /produced no SVG/)
      expect(File.exist?(File.dirname(File.read(input_path)))).to be(false)
    end
  end
end
