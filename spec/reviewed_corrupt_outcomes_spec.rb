# frozen_string_literal: true

require "spec_helper"
require_relative "../scripts/support/corrupt_outcome_contract"

RSpec.describe "Independently reviewed corrupted-input outcomes" do
  let(:manifest_path) { File.expand_path("fixtures/parity_manifest.yml", __dir__) }
  let(:ledger_path) { File.expand_path("fixtures/reviewed_corrupt_outcomes.json", __dir__) }
  let(:manifest) { YAML.safe_load_file(manifest_path) }
  let(:ledger) { JSON.parse(File.read(ledger_path)) }
  let(:contract) { Emfsvg::CorruptOutcomeContract.new(manifest: manifest, ledger: ledger) }
  let(:rejected) { Emfsvg::CorruptOutcomeContract::Rejected }
  let(:unreadable) { ledger.select { |_name, record| record.fetch("expected_outcome").fetch("kind") == "unreadable" } }
  let(:warning_records) do
    ledger.reject { |_name, record| record.fetch("expected_outcome").fetch("warnings").empty? }
  end

  it "contracts all 21 pinned inputs as 19 recoverable SVGs and two unreadable headers without observations" do
    before = [manifest_path, ledger_path].to_h { |path| [path, Digest::SHA256.file(path).hexdigest] }
    report = contract.report

    expect(ledger.keys.sort).to eq(manifest.fetch("corrupted").map { |input| input.fetch("name") }.sort)
    expect(report.fetch("status")).to eq("contracted")
    expect(report.fetch("counts")).to eq("contracted" => 21, "matched" => 0, "unresolved" => 0, "mismatch" => 0)
    expect(report.fetch("cases").map { |entry| entry.fetch("expected_outcome").fetch("kind") }.tally)
      .to eq("svg" => 19, "unreadable" => 2)
    expect(report.fetch("cases")).to all(include("status" => "contracted", "requirements" => []))
    expect(manifest.fetch("corrupted").map { |input| input.fetch("expected_outcome") }).to all(be_nil)
    expect([manifest_path, ledger_path].to_h { |path| [path, Digest::SHA256.file(path).hexdigest] }).to eq(before)
  end

  it "binds every reviewed source identity to the committed inventory" do
    manifest.fetch("corrupted").each do |input|
      expect(ledger.fetch(input.fetch("name")).fetch("source")).to eq(input.fetch("source"))
    end
  end

  it "retains explicit review and persistent independent source and policy references for every input" do
    ledger.each_value do |record|
      expect(record.fetch("reviewed")).to be(true)
      evidence = record.fetch("evidence")
      expect(evidence.map { |entry| entry.fetch("kind") }).to include("reference", "requirement")
      evidence.each do |entry|
        expect(entry.fetch("reference")).not_to match(%r{/private/tmp|/Users/})
        expect(entry.fetch("reference").strip).not_to be_empty
      end
    end
  end

  it "rejects source SHA drift in a pinned manifest input" do
    input = manifest.fetch("corrupted").first
    name = input.fetch("name")
    input.fetch("source")["sha256"] = "0" * 64

    report = contract.report
    expect(report.fetch("counts")).to eq("contracted" => 20, "matched" => 0, "unresolved" => 0, "mismatch" => 1)
    expect(report.fetch("cases").find { |entry| entry.fetch("name") == name })
      .to include("status" => "mismatch", "error" => "ledger source mismatch")
  end

  context "with a synthetic failure observation built from each reviewed unreadable expectation" do
    it "rejects a wrong header error message" do
      expect(unreadable.size).to eq(2)
      unreadable.each do |name, record|
        expected = record.fetch("expected_outcome")
        observation = { "source" => record.fetch("source"), "warnings" => expected.fetch("warnings"),
                        "svg" => nil, "output_bytes" => 0,
                        "exception" => expected.fetch("exception").merge("message" => "wrong header message") }

        expect { contract.validate_observation!(name, observation) }
          .to raise_error(rejected, "exception/cause mismatch or partial SVG")
      end
    end

    it "rejects a wrong original header failure cause" do
      expect(unreadable.size).to eq(2)
      unreadable.each do |name, record|
        expected = record.fetch("expected_outcome")
        failure = expected.fetch("exception")
        wrong_cause = failure.fetch("cause").merge("message" => "wrong cause")
        observation = { "source" => record.fetch("source"), "warnings" => expected.fetch("warnings"),
                        "svg" => nil, "output_bytes" => 0,
                        "exception" => failure.merge("cause" => wrong_cause) }

        expect { contract.validate_observation!(name, observation) }
          .to raise_error(rejected, "exception/cause mismatch or partial SVG")
      end
    end
  end

  context "with a synthetic observation for each reviewed warning case" do
    it "preserves four distinct single-line warning cases" do
      expect(warning_records.size).to eq(4)
      warnings = warning_records.values.map { |record| record.fetch("expected_outcome").fetch("warnings") }
      expect(warnings).to all(have_attributes(size: 1))
      expect(warnings.flatten).to all(match(/\A[^\n]+\n\z/))
    end

    {
      "changed warning content" => :content,
      "missing warning newline" => :newline,
      "a missing warning entry" => :missing,
      "an extra warning entry" => :extra
    }.each do |description, change|
      it "rejects #{description}" do
        expect(warning_records.size).to eq(4)
        warning_records.each do |name, record|
          warnings = record.fetch("expected_outcome").fetch("warnings")
          changed = case change
                    when :content then ["changed warning\n"]
                    when :newline then [warnings.first.chomp]
                    when :missing then []
                    when :extra then warnings + ["extra warning\n"]
                    end
          observation = { "source" => record.fetch("source"), "warnings" => changed }

          expect { contract.validate_observation!(name, observation) }.to raise_error(rejected, "warning mismatch")
        end
      end
    end
  end
end
