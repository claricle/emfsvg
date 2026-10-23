# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"
require_relative "../scripts/support/corrupt_outcome_contract"

RSpec.describe Emfsvg::CorruptOutcomeContract do
  let(:source) { { "path" => "spec/fixtures/emf-corrupted/example.emf", "sha256" => "a" * 64 } }
  let(:input) { { "name" => "example", "source" => source, "expected_outcome" => nil } }
  let(:manifest) { { "corrupted" => [input] } }
  let(:svg) { '<svg xmlns="http://www.w3.org/2000/svg"/>' }
  let(:expected) { { "kind" => "svg", "warnings" => ["reviewed warning\n"], "svg_sha256" => Digest::SHA256.hexdigest(svg) } }
  let(:evidence) { [{ "kind" => "reference", "reference" => "reviewed-reference:case-42" }] }
  let(:record) { { "reviewed" => true, "source" => source, "expected_outcome" => expected, "evidence" => evidence } }
  let(:ledger) { { "example" => record } }
  let(:contract) { described_class.new(manifest: manifest, ledger: ledger) }
  let(:observation) do
    { "source" => source, "warnings" => expected["warnings"], "svg" => svg, "output_bytes" => svg.bytesize,
      "exception" => nil }
  end
  let(:failure) { { "class" => "Emfsvg::ParseError", "message" => "invalid header", "cause" => { "class" => "Emf::FormatError", "message" => "short header" } } }

  it "reports every actual corrupted input unresolved without changing the manifest or trusting snapshots" do
    path = File.expand_path("fixtures/parity_manifest.yml", __dir__)
    before = Digest::SHA256.file(path).hexdigest
    report = described_class.new(manifest: path).report

    expect(report.fetch("status")).to eq("unresolved")
    expect(report.fetch("counts")).to eq("contracted" => 0, "matched" => 0, "unresolved" => 21, "mismatch" => 0)
    names = YAML.safe_load_file(path).fetch("corrupted").map { |entry| entry.fetch("name") }
    expect(report.fetch("cases").map { |entry| entry.fetch("name") }).to eq(names.sort)
    expect(report.fetch("cases")).to all(include("status" => "unresolved",
                                                 "requirements" => include("expected_outcome.kind")))
    expect(Digest::SHA256.file(path).hexdigest).to eq(before)
  end

  it "never promotes a bare manifest expectation or observation to a contract" do
    input["expected_outcome"] = expected
    report = described_class.new(manifest: manifest).report(observations: { "example" => observation })

    expect(report.fetch("cases").first).to include("status" => "unresolved", "source" => source)
    expect(report.fetch("counts").fetch("matched")).to eq(0)
  end

  it "requires explicit review attestation and independent evidence rather than an observation reference" do
    record["reviewed"] = false
    record["evidence"] = [{ "kind" => "snapshot", "reference" => "current-run.json" }]

    expect(contract.report.fetch("cases").first.fetch("requirements")).to include(
      "reviewed (explicit true attestation)", "independent requirement/reference evidence"
    )
  end

  it "reports contracted ledger values and preserves exact warnings and SVG bytes on a match" do
    expect(contract.report.fetch("cases").first).to include("status" => "contracted", "expected_outcome" => expected,
                                                            "evidence" => evidence)
    expect(contract.validate_observation!("example", observation)).to be(true)
    expect(contract.report(observations: { "example" => observation }).fetch("counts")).to include("matched" => 1,
                                                                                                   "mismatch" => 0)
  end

  it "matches a reviewed SVG outcome without a historical digest" do
    expected.delete("svg_sha256")

    expect(contract.report.fetch("cases").first.fetch("requirements")).to be_empty
    expect(contract.validate_observation!("example", observation)).to be(true)
    expect(contract.report(observations: { "example" => observation }).fetch("counts"))
      .to include("matched" => 1, "mismatch" => 0)
  end

  it "rejects an invalid supplied SVG digest" do
    expected["svg_sha256"] = "A" * 64

    expect(contract.report.fetch("cases").first.fetch("requirements"))
      .to include("expected_outcome.svg_sha256 (64 lowercase hex characters)")
  end

  it "rejects changed warnings including ordering" do
    expected["warnings"] = %w[first second]
    observation["warnings"] = %w[second first]

    expect do
      contract.validate_observation!("example", observation)
    end.to raise_error(described_class::Rejected, "warning mismatch")
  end

  it "rejects a changed SVG digest and partial or inconsistent successful reports" do
    observation["svg"] = "<svg/>"
    observation["output_bytes"] = observation["svg"].bytesize
    expect do
      contract.validate_observation!("example", observation)
    end.to raise_error(described_class::Rejected, /SVG digest/)

    observation["svg"] = svg
    observation["output_bytes"] = svg.bytesize
    observation["exception"] = failure
    expect do
      contract.validate_observation!("example",
                                     observation)
    end.to raise_error(described_class::Rejected, /exception mismatch/)
  end

  it "rejects non-SVG and malformed XML even when the reviewed digest matches" do
    ["not XML", "<svg/>", '<svg xmlns="urn:wrong"/>', '<svg xmlns="http://www.w3.org/2000/svg">'].each do |bytes|
      expected["svg_sha256"] = Digest::SHA256.hexdigest(bytes)
      observation["svg"] = bytes
      observation["output_bytes"] = bytes.bytesize

      expect { contract.validate_observation!("example", observation) }.to raise_error(
        described_class::Rejected, /invalid SVG/
      )
    end
  end

  it "rejects ledger and observation input path or hash drift" do
    %w[path sha256].each do |field|
      record["source"] = source.merge(field => "drift")
      expect(contract.report.fetch("cases").first).to include("status" => "mismatch",
                                                              "error" => "ledger source mismatch")
      record["source"] = source
      observation["source"] = source.merge(field => "drift")
      expect do
        contract.validate_observation!("example",
                                       observation)
      end.to raise_error(described_class::Rejected, "observation source mismatch")
    end
  end

  it "reports precise missing warnings, digest and failure cause requirements" do
    expected.delete("warnings")
    expected.delete("svg_sha256")
    expect(contract.report.fetch("cases").first.fetch("requirements")).to include(
      "expected_outcome.warnings (exact ordered strings)"
    )
    record["expected_outcome"] =
      { "kind" => "unreadable", "warnings" => [], "exception" => failure.merge("cause" => nil) }
    expect(contract.report.fetch("cases").first.fetch("requirements")).to include(
      "expected_outcome.exception.cause (original class/message)"
    )
  end

  context "with a reviewed unreadable outcome" do
    let(:expected) { { "kind" => "unreadable", "warnings" => [], "exception" => failure } }
    let(:observation) do
      { "source" => source, "warnings" => [], "svg" => nil, "output_bytes" => 0, "exception" => failure.dup }
    end

    it "accepts the exact typed failure and cause with zero output" do
      expect(contract.validate_observation!("example", observation)).to be(true)
    end

    it "rejects a changed exception class, message or original cause" do
      %w[class message cause].each do |field|
        observation["exception"] = failure.merge(field => "changed")
        expect do
          contract.validate_observation!("example",
                                         observation)
        end.to raise_error(described_class::Rejected, %r{exception/cause mismatch})
      end
    end

    it "rejects partial SVG or nonzero output even when the exception matches" do
      observation["svg"] = svg
      expect do
        contract.validate_observation!("example", observation)
      end.to raise_error(described_class::Rejected, /partial SVG/)
      observation["svg"] = nil
      observation["output_bytes"] = 1
      expect do
        contract.validate_observation!("example", observation)
      end.to raise_error(described_class::Rejected, /partial SVG/)
    end
  end

  context "with a reviewed upstream resource refusal" do
    let(:metadata) { { "resource" => "input_bytes", "limit" => 8, "actual" => 9 } }
    let(:failure) do
      metadata.merge("class" => "Emfsvg::ResourceLimitError", "message" => "over budget",
                     "cause" => metadata.merge("class" => "Emf::ResourceLimitError", "message" => "over budget"))
    end
    let(:expected) { { "kind" => "resource", "warnings" => [], "exception" => failure } }
    let(:observation) do
      { "source" => source, "warnings" => [], "svg" => nil, "output_bytes" => 0, "exception" => failure }
    end

    it "preserves exact upstream metadata and cause" do
      expect(contract.validate_observation!("example", observation)).to be(true)
      observation["exception"] = failure.merge("actual" => 10)
      expect do
        contract.validate_observation!("example",
                                       observation)
      end.to raise_error(described_class::Rejected, %r{exception/cause mismatch})
    end

    it "leaves invalid upstream metadata and cause contracts unresolved" do
      failure["cause"] = failure.fetch("cause").merge("actual" => 10)
      expect(contract.report.fetch("cases").first).to include(
        "status" => "unresolved",
        "requirements" => include("expected_outcome.exception resource/limit/actual and matching upstream cause")
      )
    end

    it "preserves a downstream resource refusal with an explicitly nil cause" do
      failure["cause"] = nil

      expect(contract.validate_observation!("example", observation)).to be(true)
      observation["exception"] = failure.merge("cause" => { "class" => "Invented", "message" => "cause" })
      expect { contract.validate_observation!("example", observation) }.to raise_error(
        described_class::Rejected, %r{exception/cause mismatch}
      )
    end
  end

  it "sorts cases deterministically and rejects unknown ledger or observation inputs" do
    manifest["corrupted"] << input.merge("name" => "aaa")
    expect(contract.report.fetch("cases").map { |entry| entry.fetch("name") }).to eq(%w[aaa example])
    expect(contract.report).to eq(contract.report)
    expect do
      contract.report(observations: { "unknown" => {} })
    end.to raise_error(described_class::Rejected,
                       "unknown observation inputs")
    ledger["unknown"] = record
    expect do
      described_class.new(manifest: manifest,
                          ledger: ledger)
    end.to raise_error(described_class::Rejected, "unknown ledger inputs")
  end

  it "emits a JSON unresolved CLI report and exits nonzero without invoking conversion" do
    script = File.expand_path("../scripts/support/corrupt_outcome_contract.rb", __dir__)
    path = File.expand_path("fixtures/parity_manifest.yml", __dir__)
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, path)

    expect(status.exitstatus).to eq(1)
    expect(stderr).to eq("")
    expect(JSON.parse(stdout)).to include("status" => "unresolved", "counts" => include("unresolved" => 21))
  end

  it "rejects an empty corrupted inventory rather than reporting a complete contract" do
    manifest["corrupted"] = []

    expect { contract }.to raise_error(described_class::Rejected, "invalid corrupted inventory")
  end
end
