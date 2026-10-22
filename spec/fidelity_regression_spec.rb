# frozen_string_literal: true

require "spec_helper"
require "open3"
require "tmpdir"

# Regression spec: emfsvg's EMF→SVG output must be semantically
# equivalent to libemf2svg's reference output on sampled fixtures.
#
# Uses the lossy SvgMatcher (tolerance 1.0px, ID canonicalisation,
# defs hoisting, transform-group flattening) to compare.
#
# Auto-skips if libemf2svg's binary is not available.
RSpec.describe "EMF→SVG fidelity vs libemf2svg (regression floor)" do
  let(:ref_binary) { "/Users/mulgogi/src/claricle/libemf2svg/emf2svg_ref" }
  let(:ref_lib_dir) { "/Users/mulgogi/src/claricle/libemf2svg/build" }
  emf_globs = %w[
    ../emf/spec/fixtures/emf/*.emf
    ../emf/spec/fixtures/emf-ea/*.emf
  ].freeze

  def ref_available?
    File.executable?(ref_binary)
  end

  def generate_reference(emf_path)
    output_path = File.join(Dir.mktmpdir, "#{File.basename(emf_path, '.emf')}.svg")
    env = { "DYLD_LIBRARY_PATH" => ref_lib_dir }
    _, _, status = Open3.capture3(env, ref_binary, emf_path, output_path)
    return nil unless status.success?

    File.binread(output_path)
  ensure
    File.delete(output_path) if output_path && File.exist?(output_path)
  end

  # Collect a representative sample (first 5 from each glob) to keep
  # spec runtime reasonable. Full 208-fixture scan lives in
  # scripts/run_emf_svg_compare.rb.
  before { skip "libemf2svg not available at #{ref_binary}" unless ref_available? }

  base_dir = File.expand_path(File.join(__dir__, ".."))
  fixtures = emf_globs.flat_map do |g|
    Dir.glob(File.expand_path(g, base_dir)).first(5)
  end.sort

  fixtures.each do |emf_path|
    name = File.basename(emf_path, ".emf")

    it "#{name} emfsvg output matches libemf2svg semantically" do
      emfsvg_svg = Emfsvg.from_file(emf_path)
      ref_svg = generate_reference(emf_path)

      expect(ref_svg).not_to be_nil, "libemf2svg failed to render #{name}"

      comparison = Emfsvg::SvgMatcher.compare(emfsvg_svg, ref_svg, tolerance: 1.0)
      expect(comparison.equal).to be(true), comparison.reason || "semantic mismatch"
    end
  end
end
