# frozen_string_literal: true

# The native render ledger (claricle/emf#91): the Rust EMF -> VIM -> SVG
# conversion and the Ruby lane must answer the same corpus drawings with the
# same output. Runs only where the eikogram-ffi cdylib is loadable (CI's
# native-runtime job, or a local `cargo build -p eikogram-ffi --release`);
# elsewhere it is skipped and the Ruby path is what the rest of the suite
# covers.
#
# Comparison is byte equality, with the emf88 gate's canonical quirk
# normalization as the recorded equivalence (the SVG model declares the
# renderer's tag-grammar whitespace non-representable; the same
# normalization is applied to both sides, quoted values never touched).
#
# The ledger line warns, e.g. `native emfsvg render: 14 same
# (0 raw, 14 quirk-normalized), 0 unported`.
require "spec_helper"

RSpec.describe Emfsvg::Runtime do
  let(:built_library) { saved_native_library || Emfsvg::Native.library_path }
  let(:fixture_root) { ENV.fetch("EMF_FIXTURE_ROOT", nil) }

  # The smoke subset: deterministic across the corpus's source groups and
  # required to include EMF+ (emf-ea) drawings — the parity corpus's smoke
  # subset, never the whole corpus (the emf88 gate owns that).
  let(:subset) do
    root = fixture_root
    return [] if root.nil?

    { "emf" => 5, "emf-ea" => 5, "simple" => 4 }.flat_map do |group, take|
      directory = File.join(root, "spec/fixtures", group)
      Dir.glob(File.join(directory, "*.emf")).first(take)
    end
  end

  around do |example|
    with_fresh_runtime do
      with_native_library(built_library)
      example.run
    end
  end

  it "renders the smoke subset identically through Rust and Ruby" do
    skip "eikogram-ffi cdylib not built in this checkout" if built_library.nil?
    skip "corpus not configured (EMF_FIXTURE_ROOT unset)" if fixture_root.nil?

    expect(subset.size).to be >= 10
    expect(subset).to include(a_string_matching(%r{/emf-ea/}),
                              a_string_matching(%r{/emf/}),
                              a_string_matching(%r{/simple/}))

    same_raw = 0
    same_normalized = 0
    unported = []

    subset.each do |path|
      bytes = File.binread(path)
      with_runtime_mode("ruby")
      ruby_bytes = described_class.from_bytes(bytes).to_s.b

      with_runtime_mode("native")
      begin
        native_bytes = described_class.from_bytes(bytes).to_s.b
      rescue Emfsvg::Error, Emfsvg::Native::NativeError => e
        unported << "#{path}: #{e.class}: #{e.message[0, 120]}"
        next
      end

      if native_bytes == ruby_bytes
        same_raw += 1
        same_normalized += 1
      elsif normalized(native_bytes) == normalized(ruby_bytes)
        same_normalized += 1
      else
        unported << "#{path}: first difference at byte #{first_difference(ruby_bytes, native_bytes)}"
      end
    end

    warn "native emfsvg render: #{same_normalized} same " \
         "(#{same_raw} raw, #{same_normalized - same_raw} quirk-normalized), " \
         "#{unported.size} unported"
    unported.each { |entry| warn "  unported #{entry}" }

    expect(unported).to eq([])
    expect(same_normalized).to eq(subset.size)
  end

  private

  def normalized(svg)
    Emfsvg::SpecSupport::QuirkNormalization.normalize(svg)
  end

  def first_difference(expected, actual)
    common = expected.bytes.zip(actual.bytes).take_while { |a, b| a == b }.count
    common.to_s
  end
end
