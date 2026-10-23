# frozen_string_literal: true

require "spec_helper"
require "support/parity_comparison"
require "yaml"

RSpec.describe Emfsvg::SpecSupport::ParityComparison do
  it "reports a suffix-only byte difference with bounded context and generated digest" do
    expected = "a" * 200
    actual = "#{expected}x"
    message = described_class.difference(group: "round_trip", name: "sample", reference: "sample.svg",
                                         expected: expected, actual: actual)
    expect(message).to include("round_trip: sample", "reference=sample.svg", "first difference=200",
                               Digest::SHA256.hexdigest(actual))
    expect(message.bytesize).to be < 500
  end

  it "reports the first differing byte in binary strings" do
    message = described_class.difference(group: "compatibility", name: "sample", reference: "sample.svg",
                                         expected: "a\xFF".b, actual: "a\xFE".b)
    expect(message).to include("first difference=1", 'expected excerpt="a\\xFF"', 'generated excerpt="a\\xFE"')
  end

  it "sorts inventory rows by basename and detects changed output digests" do
    rows = [%w[b source reference output], %w[a source reference output]]
    expected = Digest::SHA256.hexdigest("a\tsource\treference\toutput\nb\tsource\treference\toutput\n")
    expect(described_class.inventory_digest(rows)).to eq(expected)
    changed = [%w[a source reference changed], rows.first]
    expect(described_class.inventory_digest(changed)).not_to eq(expected)
  end

  it "pins expected generated output to C golden hashes in the compatibility inventory" do
    manifest = YAML.safe_load_file(File.expand_path("fixtures/parity_manifest.yml", __dir__))
    rows = manifest.fetch("fixtures").map do |entry|
      golden = entry.fetch("golden").fetch("sha256")
      [entry.fetch("name"), entry.fetch("source").fetch("sha256"), golden, golden]
    end
    expect(manifest.fetch("inventories").fetch("compatibility_columns")).to eq(%w[source golden generated])
    expect(described_class.inventory_digest(rows)).to eq(manifest.fetch("inventories").fetch("compatibility_sha256"))
  end

  it "rejects unverified historical C provenance" do
    manifest = YAML.safe_load_file(File.expand_path("fixtures/parity_manifest.yml", __dir__))
    provenance = manifest.fetch("provenance").fetch("c_reference").merge(
      "status" => "unverified_historical_artifacts", "source_revision" => nil
    )
    errors = described_class.c_provenance_errors(provenance)
    expect(errors).to include('status must be verified (got "unverified_historical_artifacts")',
                              "source_revision must be a full commit SHA")
  end
end
