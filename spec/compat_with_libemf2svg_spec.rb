# frozen_string_literal: true

require "spec_helper"
require "emfsvg/compat"

# Comparison spec against libemf2svg (the C reference implementation).
#
# emfsvg is a clean-room rewrite that handles a SUBSET of EMF records.
# These specs quantify the gap and guard against regressions. They do
# NOT assert byte-identical output — that would require implementing
# all 246 record handlers in libemf2svg.
#
# The spec auto-skips if libemf2svg's binary is not available.
# To enable: build libemf2svg at ../libemf2svg/ (cmake + make), then
# set EMF2SVG_REF_PATH and EMF2SVG_REF_LIB_DIR env vars if non-default.

# Fixture paths resolved at file load (top-level constants, not in block).
EMF_PATHS = (Dir.glob("../emf/spec/fixtures/emf/*.emf") +
             Dir.glob("../emf/spec/fixtures/emf-ea/*.emf") +
             Dir.glob("../emf/spec/fixtures/simple/*.emf")).freeze

# Element types emfsvg is allowed to emit. Includes <line> which
# libemf2svg doesn't use (it unifies to <path>) — stylistic difference.
VALID_SVG_DRAWING_ELEMENTS = %w[svg g path rect ellipse line polyline polygon
                                circle text image defs clippath use].freeze

RSpec.describe "emfsvg vs libemf2svg reference" do
  before do
    unless Emfsvg::Compat.ref_binary_available?
      skip "libemf2svg reference binary not found. Build libemf2svg at " \
           "../libemf2svg/ to enable this spec, or set EMF2SVG_REF_PATH."
    end
  end

  describe "for every fixture" do
    EMF_PATHS.each do |path|
      it "produces well-formed SVG for #{File.basename(path)}" do
        svg = Emfsvg::Compat.generate_emfsvg(path)
        expect(svg).to start_with("<?xml")
        expect(svg).to include("<svg")
        expect(svg).to include("</svg>")
        root = Emfsvg::Compat.parse_svg(svg)
        expect(root).not_to be_nil
      end

      it "libemf2svg also produces well-formed SVG for #{File.basename(path)}" do
        ref = Emfsvg::Compat.generate_reference(path)
        expect(ref).to start_with("<?xml")
        expect(ref).to include("<svg")
        root = Emfsvg::Compat.parse_svg(ref)
        expect(root).not_to be_nil
      end
    end
  end

  describe "structural comparison" do
    # Sample 10 fixtures to keep spec runtime reasonable.
    # Full comparison is in scripts/run_compat_check.rb (developer tooling).
    sample = Dir.glob("../emf/spec/fixtures/emf/*.emf").first(5) +
             Dir.glob("../emf/spec/fixtures/emf-ea/*.emf").first(3) +
             Dir.glob("../emf/spec/fixtures/simple/*.emf").first(2)

    sample.each do |path|
      it "#{File.basename(path)} emfsvg emits only valid SVG drawing elements" do
        out = Emfsvg::Compat.generate_emfsvg(path)
        out_counts = Emfsvg::Compat.count_elements(Emfsvg::Compat.parse_svg(out))

        foreign = out_counts.keys - VALID_SVG_DRAWING_ELEMENTS
        expect(foreign).to be_empty,
                           "emfsvg emitted non-SVG element types: #{foreign.inspect}"
      end
    end
  end

  describe "regression: aggregate output ratio" do
    it "emfsvg produces at least 10% of libemf2svg's total byte output" do
      # Regression floor. Current ratio is ~43% across all fixtures and
      # ~13% on the simple fixture (which is EMF+-heavy). 10% is a
      # conservative floor that catches catastrophic regressions without
      # being noisy. Tighten as handlers are added.
      results = Emfsvg::Compat.compare_glob("../emf/spec/fixtures/simple/*.emf")
      total_ref = results.sum(&:ref_bytes)
      total_out = results.sum(&:emfsvg_bytes)
      ratio = total_ref.zero? ? 0 : total_out.to_f / total_ref
      expect(ratio).to be >= 0.10,
                       "emfsvg output ratio dropped to #{(ratio * 100).round(1)}% (regression)"
    end
  end
end
