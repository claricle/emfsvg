# frozen_string_literal: true

# The runtime switch behaviors (claricle/emf#91): auto =
# native-when-loadable, ruby forces the Ruby lane, native demands the
# engine and raises the NAMED error when missing (the etassia#491 law —
# never a silent switch).
#
# No test doubles: the switch is driven through real env values and the
# real library (built locally or in CI's native job). Where the native
# library is not built, those examples are skipped — every other CI job
# proves the Ruby-only path.
require "spec_helper"
require "tmpdir"

RSpec.describe Emfsvg::Runtime do
  let(:built_library) { saved_native_library || Emfsvg::Native.library_path }

  around do |example|
    with_fresh_runtime { example.run }
  end

  describe ".mode" do
    it "defaults to auto" do
      expect(described_class.mode).to eq("auto")
    end

    it "treats an empty value as auto" do
      with_runtime_mode("")
      expect(described_class.mode).to eq("auto")
    end

    described_class::MODES.each do |value|
      it "accepts #{value}" do
        with_runtime_mode(value)
        expect(described_class.mode).to eq(value)
      end
    end

    it "rejects an unknown mode naming the env key and the value" do
      with_runtime_mode("jit")
      expect { described_class.mode }
        .to raise_error(ArgumentError, /EMFSVG_RUNTIME.*"jit"/)
    end
  end

  describe ".native?" do
    it "is false when no library exists" do
      with_missing_native_library
      expect(described_class).not_to be_native
    end

    it "probes once and reuses the answer until reset" do
      with_missing_native_library
      expect(described_class).not_to be_native

      # A changed env does not re-open the question in the same process.
      ENV["EMFSVG_NATIVE_LIB"] = File.join("", "other-emfsvg-spec", "libeikogram_ffi.dylib")
      expect(described_class).not_to be_native

      described_class.reset!
      # The re-probe consults the loader afresh: still no library file.
      expect(described_class).not_to be_native
    end

    it "is true when the library is loadable" do
      skip_unless_native_built
      with_native_library(built_library)
      expect(described_class).to be_native
    end

    it "raises the named loader error when the file exists but is not a library" do
      Dir.mktmpdir do |directory|
        impostor = File.join(directory, "libeikogram_ffi.dylib")
        File.write(impostor, "not a dylib")
        with_native_library(impostor)

        expect { described_class.native? }
          .to raise_error(Emfsvg::Native::NativeError, /Cannot load|failed to load/)
      end
    end

    it "accepts the real library's ABI version (the loader's gate)" do
      skip_unless_native_built
      with_native_library(built_library)

      # The load itself is the check: a library answering a version other
      # than 1 is refused before any render call, so a green probe proves
      # the version contract held.
      expect(Emfsvg::Native.library.abi_version).to eq(1)
      expect(described_class).to be_native
    end
  end

  describe ".engine" do
    it "answers :ruby when the library is missing" do
      with_missing_native_library
      expect(described_class.engine).to eq(:ruby)
    end

    it "answers :ruby in ruby mode even when the library is loadable" do
      skip_unless_native_built
      with_native_library(built_library)
      with_runtime_mode("ruby")
      expect(described_class.engine).to eq(:ruby)
    end

    it "answers :native in native mode" do
      skip_unless_native_built
      with_native_library(built_library)
      with_runtime_mode("native")
      expect(described_class.engine).to eq(:native)
    end

    it "answers :native in auto mode when the library is loadable" do
      skip_unless_native_built
      with_native_library(built_library)
      expect(described_class.engine).to eq(:native)
    end
  end

  describe ".from_bytes" do
    let(:emf_path) do
      Emfsvg::SpecSupport::FixturePath.fixture("image1.emf")
    end
    let(:emf_bytes) { File.binread(emf_path) }

    describe "in auto mode" do
      it "answers from the Ruby lane when the library is missing" do
        with_missing_native_library
        expect(described_class.from_bytes(emf_bytes))
          .to eq(Emfsvg.from_bytes(emf_bytes))
        expect(described_class.engine).to eq(:ruby)
      end

      it "answers from the native engine with the same bytes when it is loadable" do
        skip_unless_native_built
        with_native_library(built_library)
        native_output = described_class.from_bytes(emf_bytes).b

        expect(same_render_output?(native_output, Emfsvg.from_bytes(emf_bytes).b)).to be(true)
      end
    end

    describe "in ruby mode" do
      it "forces the Ruby lane even when the library is loadable" do
        skip_unless_native_built
        with_native_library(built_library)
        with_runtime_mode("ruby")

        expect(described_class.from_bytes(emf_bytes))
          .to eq(Emfsvg.from_bytes(emf_bytes))
      end
    end

    describe "in native mode" do
      it "raises the named error when the engine is missing" do
        with_missing_native_library
        with_runtime_mode("native")

        expect { described_class.from_bytes(emf_bytes) }
          .to raise_error(
            described_class::EngineUnavailableError,
            /EMFSVG_RUNTIME.*native engine.*not loadable/
          )
      end

      it "answers from the native engine when it is loadable" do
        skip_unless_native_built
        with_native_library(built_library)
        with_runtime_mode("native")

        native_output = described_class.from_bytes(emf_bytes).b

        expect(same_render_output?(native_output, Emfsvg.from_bytes(emf_bytes).b)).to be(true)
      end

      it "refuses non-default options naming the ABI rule" do
        skip_unless_native_built
        with_native_library(built_library)
        with_runtime_mode("native")

        expect { described_class.from_bytes(emf_bytes, width: 512.0) }
          .to raise_error(ArgumentError, /native v1 render ABI carries no options/)
      end

      it "accepts default options unchanged" do
        skip_unless_native_built
        with_native_library(built_library)
        with_runtime_mode("native")

        native_output = described_class.from_bytes(emf_bytes, verbose: false).b

        expect(same_render_output?(native_output, Emfsvg.from_bytes(emf_bytes).b)).to be(true)
      end
    end
  end

  describe ".drawing" do
    let(:emf_path) do
      Emfsvg::SpecSupport::FixturePath.fixture("image1.emf")
    end
    let(:emf_bytes) { File.binread(emf_path) }
    let(:steps) { [{ "name" => "render" }] }

    it "answers from the Ruby lane when the library is missing" do
      with_missing_native_library

      expect(described_class.drawing(emf_bytes, steps: steps))
        .to eq(Emfsvg.from_bytes(emf_bytes))
    end

    it "answers from the native engine with the same bytes when loadable" do
      skip_unless_native_built
      with_native_library(built_library)

      with_runtime_mode("ruby")
      ruby_output = described_class.drawing(emf_bytes, steps: steps)

      with_runtime_mode("native")
      native_output = described_class.drawing(emf_bytes, steps: steps).b

      expect(same_render_output?(native_output, ruby_output.b)).to be(true)
    end

    it "raises the named error when native mode demands a missing engine" do
      with_missing_native_library
      with_runtime_mode("native")

      expect { described_class.drawing(emf_bytes, steps: steps) }
        .to raise_error(described_class::EngineUnavailableError)
    end

    it "refuses a spec the v1 native ABI does not implement" do
      skip_unless_native_built
      with_native_library(built_library)
      with_runtime_mode("native")

      expect do
        described_class.drawing(emf_bytes, steps: [{ "name" => "transpose" }])
      end.to raise_error(ArgumentError, /implements only/)
    end
  end

  private

  def skip_unless_native_built
    skip "eikogram-ffi cdylib not built in this checkout" if built_library.nil?
  end
end
