# frozen_string_literal: true

require "spec_helper"
require "support/parity_corpus"
require "support/parity_comparison"

# The emfsvg-generated artifacts are the round-trip inputs and byte oracles.
RSpec.describe "SVG → EMF → SVG round-trip (golden master)" do
  corpus = Emfsvg::SpecSupport::ParityCorpus.new
  corpus.verify!
  comparison = Emfsvg::SpecSupport::ParityComparison

  corpus.fixtures.each do |entry|
    path = corpus.artifact_path(entry, "round_trip")
    name = entry.fetch("name")

    it "#{name}.svg round-trips byte-equal" do
      expected = File.binread(path)
      actual = Emfsvg.from_bytes(Emfsvg.from_svg(expected))
      message = lambda do
        comparison.difference(group: "round_trip", name: name, reference: path,
                              expected: expected, actual: actual)
      end
      expect(actual.b == expected).to be(true), message
    end
  end

  it "matches the exact sorted round-trip artifact inventory" do
    actual = comparison.artifact_inventory(corpus, ["round_trip"])
    expect(actual).to eq(corpus.manifest.fetch("inventories").fetch("round_trip_sha256"))
  end
end
