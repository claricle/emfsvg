# frozen_string_literal: true

require "spec_helper"
require "support/parity_corpus"

# Explicit live audit: bundle exec rspec spec/fidelity_regression_spec.rb --tag live_reference
RSpec.describe "EMF→SVG fidelity vs libemf2svg (regression floor)", :live_reference do
  it "matches the pinned corpus semantically against the configured C reference" do
    Emfsvg::Compat.validate_reference!
    fixtures = Emfsvg::SpecSupport::ParityCorpus.new.source_paths
    expect(fixtures).not_to be_empty

    fixtures.each do |emf_path|
      emfsvg_svg = Emfsvg.from_file(emf_path)
      ref_svg = Emfsvg::Compat.generate_reference(emf_path)
      comparison = Emfsvg::SvgMatcher.compare(emfsvg_svg, ref_svg, tolerance: 1.0)

      expect(comparison.equal).to be(true), "#{File.basename(emf_path)}: #{comparison.reason || 'semantic mismatch'}"
    end
  end
end
