# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Pinned external parity inventory" do
  subject(:corpus) { Emfsvg::SpecSupport::ParityCorpus.new }

  it "verifies every source and committed artifact at the pinned corpus revision" do
    expect(corpus.verify!).to equal(corpus)
    expect(corpus.fixtures.size).to eq(208)
    expect(corpus.corrupted.size).to eq(21)
  end

  it "retains the exact 208/209/426 comparison composition" do
    expect(corpus.manifest.fetch("groups")).to eq(
      "golden" => 208, "round_trip" => 209, "compatibility" => 426,
      "compatibility_composition" => {
        "ruby_to_c_golden" => 208, "c_artifact_integrity" => 208, "fixed_sample" => 9, "aggregate_inventory" => 1
      }
    )
  end
end
