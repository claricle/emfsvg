# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::SpecSupport::GoldenRegeneration do
  include Emfsvg::SpecSupport::GoldenRegenerationFixture

  it "checks the complete unchanged candidate without writing baseline files or the manifest" do
    with_regeneration do |runner, project, manifest, output, _corpus|
      before = regeneration_snapshot(project, manifest)
      expect(runner.run(check: true)).to be(true)
      expect(regeneration_snapshot(project, manifest)).to eq(before)
      report = JSON.parse(output.string)
      expect(report.fetch("changed_basenames")).to eq([])
      expect(report.fetch("groups").slice("golden", "round_trip", "compatibility")).to eq(
        "golden" => 208, "round_trip" => 209, "compatibility" => 426
      )
    end
  end

  it "fails check with actionable differences and preserves every baseline byte" do
    with_regeneration(changed: true) do |runner, project, manifest, output, _corpus|
      before = regeneration_snapshot(project, manifest)
      expect(regeneration_check_exit(runner, output)).to eq(1)
      expect(regeneration_snapshot(project, manifest)).to eq(before)
      difference = JSON.parse(output.string).fetch("differences").first
      expect(difference).to include("group" => "golden", "basename" => "test-000")
      expect(difference.fetch("generated_sha256")).not_to eq(difference.fetch("expected_sha256"))
      expect(difference.fetch("first_different_byte")).to be_positive
      expect(difference.fetch("reference")).to end_with("/golden/test-000.svg")
    end
  end

  it "preserves all committed artifacts when a later conversion fails after earlier success" do
    with_regeneration(fail_name: "test-001") do |runner, project, manifest, _output, _corpus|
      before = regeneration_snapshot(project, manifest)
      expect do
        runner.run
      end.to raise_error(described_class::Error,
                         /golden conversion failed for test-001.*synthetic conversion failed/)
      expect(regeneration_snapshot(project, manifest)).to eq(before)
      expect(Dir.glob(File.join(project, "spec/fixtures/.golden-regeneration-*"))).to be_empty
    end
  end

  it "rejects incomplete inventory before modifying committed artifacts" do
    with_regeneration do |runner, project, manifest, _output, corpus|
      File.write(File.join(project, "spec/fixtures/golden/unexpected.svg"), "unexpected")
      before = regeneration_snapshot(project, manifest)
      expect { runner.run }.to raise_error(Emfsvg::SpecSupport::ParityCorpus::SetupError, /unexpected.svg/)
      expect(regeneration_snapshot(project, manifest)).to eq(before)
      expect(corpus.fixtures.size).to eq(208)
    end
  end

  it "preserves unexpected non-SVG files rather than discarding them during promotion" do
    with_regeneration do |runner, project, manifest, _output, _corpus|
      File.write(File.join(project, "spec/fixtures/golden/notes.txt"), "keep these bytes")
      before = regeneration_snapshot(project, manifest)
      expect { runner.run }.to raise_error(described_class::Error, /committed inventory mismatch.*notes.txt/)
      expect(regeneration_snapshot(project, manifest)).to eq(before)
    end
  end

  it "promotes both verified sets and their coherent manifest with review metadata" do
    with_regeneration(changed: true) do |runner, project, manifest, output, corpus|
      expect(runner.run).to be(true)
      updated = Emfsvg::SpecSupport::ParityCorpus.new(root: corpus.root, project_root: project, manifest_path: manifest)
      expect(updated.verify!).to equal(updated)
      expect(File.binread(updated.artifact_path(updated.fixtures.first, "golden"))).to end_with("changed")
      report = JSON.parse(output.string)
      expect(report.fetch("changed_basenames").size).to eq(208)
      expect(report.fetch("provenance").fetch("c_reference").fetch("source_revision")).to eq("a" * 40)
      expect(report.fetch("commands").fetch("regeneration")).to end_with("--write")
      expect(Dir.glob(File.join(project, "spec/fixtures/.golden-regeneration-*"))).to be_empty
    end
  end

  it "refuses promotion with unverified historical C provenance" do
    with_regeneration do |runner, project, manifest, _output, corpus|
      corpus.manifest.fetch("provenance").fetch("c_reference")["status"] = "unverified_historical_artifacts"
      before = regeneration_snapshot(project, manifest)
      expect { runner.run }.to raise_error(described_class::Error, /verified c_reference provenance/)
      expect(regeneration_snapshot(project, manifest)).to eq(before)
    end
  end

  it "rolls back earlier promoted paths when a later filesystem operation fails" do
    Dir.mktmpdir("golden-promotion") do |directory|
      first = File.join(directory, "first")
      second = File.join(directory, "second")
      candidate = File.join(directory, "candidate")
      File.write(first, "first original")
      File.write(second, "second original")
      File.write(candidate, "replacement")
      promotion = described_class::Promotion.new([[candidate, first], [File.join(directory, "missing"), second]],
                                                 directory)
      expect { promotion.run }.to raise_error(described_class::Error, /original artifacts restored/)
      expect(File.binread(first)).to eq("first original")
      expect(File.binread(second)).to eq("second original")
    end
  end
end
