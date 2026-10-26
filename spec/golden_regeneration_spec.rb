# frozen_string_literal: true

require "spec_helper"
require "timeout"

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
    with_regeneration(changed: true) do |_runner, project, manifest, output, corpus|
      before = regeneration_snapshot(project, manifest)
      expect(regeneration_check_exit(corpus, project, manifest, output)).to eq(1)
      expect(regeneration_snapshot(project, manifest)).to eq(before)
      difference = JSON.parse(output.string).fetch("differences").first
      expect(difference).to include("group" => "golden", "basename" => "test-000")
      expect(difference.fetch("generated_sha256")).not_to eq(difference.fetch("expected_sha256"))
      expect(difference.fetch("first_different_byte")).to be_positive
      expect(difference.fetch("reference")).to end_with("/golden/test-000.svg")
    end
  end

  it "converts each frozen SVG through EMF while the reference receives the original source" do
    with_regeneration do |_runner, project, manifest, output, corpus|
      sources = []
      svg_inputs = []
      emf_inputs = []
      reference = lambda do |source|
        sources << source
        File.binread(corpus.artifact_path(corpus.fixtures.fetch(sources.length - 1), "golden"))
      end
      svg_to_emf = lambda do |svg|
        svg_inputs << svg
        "converted EMF:#{svg}"
      end
      renderer = lambda do |emf|
        emf_inputs << emf
        emf.delete_prefix("converted EMF:")
      end
      runner = described_class.new(corpus: corpus, project_root: project, manifest_path: manifest,
                                   reference: reference, renderer: renderer, svg_to_emf: svg_to_emf, output: output)
      before = regeneration_snapshot(project, manifest)
      expect(runner.run(check: true)).to be(true)
      expect(sources).to eq(corpus.fixtures.map { |entry| corpus.source_path(entry) })
      expect(svg_inputs).to eq(corpus.fixtures.map { |entry| File.binread(corpus.artifact_path(entry, "round_trip")) })
      expect(emf_inputs).to eq(svg_inputs.map { |svg| "converted EMF:#{svg}" })
      expect(regeneration_snapshot(project, manifest)).to eq(before)
      expect(JSON.parse(output.string).fetch("commands").fetch("round_trip")).to eq(
        "Emfsvg.from_bytes(Emfsvg.from_svg(File.binread(FROZEN_ROUND_TRIP.svg)))"
      )
    end
  end

  it "fails check and refuses promotion when the frozen round-trip output drifts" do
    with_regeneration(round_trip_changed: true) do |runner, project, manifest, output, corpus|
      before = regeneration_snapshot(project, manifest)
      expect(regeneration_check_exit(corpus, project, manifest, output)).to eq(1)
      report = JSON.parse(output.string)
      expect(report.fetch("difference_count")).to eq(208)
      expect(report.fetch("differences").first).to include("group" => "round_trip", "basename" => "test-000")
      expect { runner.run }.to raise_error(described_class::Error, /Frozen round-trip artifacts changed/)
      expect(regeneration_snapshot(project, manifest)).to eq(before)
      expect(Dir.glob(File.join(project, "spec/fixtures/.golden-regeneration-*"))).to be_empty
    end
  end

  it "preserves every baseline when a later SVG conversion fails" do
    with_regeneration(round_trip_fail_name: "test-001") do |runner, project, manifest, _output, _corpus|
      before = regeneration_snapshot(project, manifest)
      expect { runner.run(check: true) }.to raise_error(
        described_class::Error, /round_trip conversion failed for test-001.*synthetic SVG conversion failed/
      )
      expect { runner.run }.to raise_error(described_class::Error, /synthetic SVG conversion failed/)
      expect(regeneration_snapshot(project, manifest)).to eq(before)
      expect(Dir.glob(File.join(project, "spec/fixtures/.golden-regeneration-*"))).to be_empty
    end
  end

  it "preserves all committed artifacts when a later conversion fails after earlier success" do
    with_regeneration(fail_name: "test-001") do |runner, project, manifest, _output, _corpus|
      before = regeneration_snapshot(project, manifest)
      expect do
        runner.run
      end.to raise_error(described_class::Error,
                         /golden conversion failed for test-001.*synthetic conversion failed/)
      expect { runner.run(check: true) }.to raise_error(described_class::Error, /synthetic conversion failed/)
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
      expect { runner.run(check: true) }.to raise_error(Emfsvg::SpecSupport::ParityCorpus::SetupError, /unexpected.svg/)
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

  it "promotes verified references and their manifest while retaining every frozen round-trip byte" do
    with_regeneration(changed: true) do |runner, project, manifest, output, corpus|
      frozen_bytes = corpus.fixtures.map { |entry| File.binread(corpus.artifact_path(entry, "round_trip")) }
      expect(runner.run).to be(true)
      expect(corpus.fixtures.map do |entry|
        File.binread(corpus.artifact_path(entry, "round_trip"))
      end).to eq(frozen_bytes)
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

  it "refuses promotion with a whitespace-only C build recipe" do
    with_regeneration do |runner, project, manifest, _output, corpus|
      corpus.manifest.fetch("provenance").fetch("c_reference")["build_recipe"] = " \n\t"
      before = regeneration_snapshot(project, manifest)
      expect { runner.run }.to raise_error(described_class::Error, /verified c_reference provenance/)
      expect(regeneration_snapshot(project, manifest)).to eq(before)
    end
  end

  it "rejects a competing process and releases its regular-file lock after an error" do
    with_regeneration do |runner, project, manifest, _output, _corpus|
      before = regeneration_snapshot(project, manifest)
      parent = File.join(project, "spec/fixtures")
      command = regeneration_process("lock", parent)
      Open3.popen3({ "TMPDIR" => File.dirname(project) }, *command) do |input, output, error, process|
        begin
          expect(Timeout.timeout(10) { output.gets }).to eq("locked\n")
          expect { runner.run(check: true) }.to raise_error(described_class::Error, /Another golden regeneration/)
        ensure
          input.close
        end
        expect(process.value.exitstatus).to eq(1)
        expect(error.read).to include("synthetic lock failure")
      end
      expect(runner.run(check: true)).to be(true)
      expect(runner.run(check: true)).to be(true)
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
