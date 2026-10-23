# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::SpecSupport::CorruptedResilienceFixture do
  include Emfsvg::SpecSupport::ResourceCalibrationFixture

  it "checks every declared corrupt input against qualified native Linux limits" do
    begin
      Emfsvg::ResourceCalibration::Prerequisites.verify!(ParityProvenance::DEFAULT_MANIFEST,
                                                         ENV.fetch("EMF_FIXTURE_ROOT", ""))
    rescue Emfsvg::ResourceCalibration::Rejected => e
      provenance = YAML.safe_load_file(ParityProvenance::DEFAULT_MANIFEST).fetch("provenance")
      raise if provenance.dig("runtime", "status") == "qualified" &&
               provenance.dig("native_library", "status") == "qualified"

      skip "Corrupt corpus qualification unavailable: #{e.message}"
    end
    described_class.new.run(manifest: ParityProvenance::DEFAULT_MANIFEST,
                            fixture_root: ENV.fetch("EMF_FIXTURE_ROOT"),
                            baseline: File.expand_path("fixtures/resource_limits/emfsvg-v1.yml", __dir__))
  end

  context "with small synthetic caller mechanics (not production qualification)" do
    around do |example|
      Dir.mktmpdir("emfsvg-resilience-mechanics-") do |directory|
        @directory = directory
        @manifest = File.join(directory, "manifest.yml")
        @baseline = File.join(directory, "baseline.yml")
        example.run
      end
    end

    let(:outcome) { { "kind" => "svg", "warnings" => [], "svg_sha256" => "2" * 64 } }
    let(:inputs) { %w[one.emf two.emf].map { |name| calibration_input(name).merge("expected_outcome" => outcome) } }
    let(:adapter) { calibration_adapter(inputs) }
    let(:qualification) { double("explicit synthetic qualification", verify!: adapter) }
    let(:runner) { double("bounded runner", run: calibration_report) }
    let(:caller) { described_class.new(qualification: qualification, runner: runner) }

    before do
      corrupt = inputs.map do |input|
        { "name" => File.basename(input.fetch("name"), ".emf"),
          "source" => input.slice("sha256").merge("path" => input.fetch("name")),
          "expected_outcome" => input.fetch("expected_outcome") }
      end
      File.write(@manifest, YAML.dump(JSON.parse(JSON.generate("corrupted" => corrupt))))
      document = Emfsvg::ResourceCalibration::Session.new(adapter: adapter, caps: calibration_caps,
                                                          runner: runner).collect
      Emfsvg::ResourceCalibration::Baseline.write!(@baseline, document)
    end

    let(:run_caller) do
      -> { caller.run(manifest: @manifest, fixture_root: @directory, baseline: @baseline) }
    end

    it "checks all selected cases in order, three times, using stored ceilings and an intact sentinel" do
      before = File.binread(@baseline)
      expect(qualification).to receive(:verify!).with(@manifest, @directory).and_return(adapter)
      inputs.each do |input|
        expect(runner).to receive(:run).with(hash_including(basename: input.fetch("name"),
                                                            timeout_seconds: 3, rss_cap_mib: 67, as_cap_mib: 137,
                                                            authoritative: true)) do |options|
          command = options.fetch(:command)
          sentinel = command.fetch(3)
          expect(File.file?(sentinel)).to be(true)
          expect(File.read(sentinel)).to include("called")
          expect(command.last).to eq("synthetic-child")
          calibration_report
        end.ordered.exactly(3).times
      end
      expect(run_caller.call.fetch("samples").size).to eq(6)
      expect(File.binread(@baseline)).to eq(before)
    end

    it "refuses qualification rejection before touching the baseline or starting children" do
      allow(qualification).to receive(:verify!).and_raise(Emfsvg::ResourceCalibration::Rejected, "unqualified")
      File.delete(@baseline)
      expect(runner).not_to receive(:run)
      expect { run_caller.call }.to raise_error(Emfsvg::ResourceCalibration::Rejected, "unqualified")
    end

    it "rejects missing, duplicate, or altered corrupt selection before child execution" do
      changed = inputs.first.merge("expected_outcome" => outcome.merge("warnings" => ["changed\n"]))
      [inputs.drop(1), inputs + [inputs.first],
       [inputs.first.merge("sha256" => "3" * 64), inputs.last], [changed, inputs.last]].each do |bad|
        allow(adapter).to receive(:inputs).and_return(bad)
        expect(runner).not_to receive(:run)
        expect { run_caller.call }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /selection drift/)
      end
    end

    it "rejects incomplete expected outcomes before child execution" do
      resource = { "kind" => "resource", "warnings" => [],
                   "exception" => { "class" => "Emfsvg::ResourceLimitError", "message" => "bounded", "cause" => nil } }
      [nil, {}, { "kind" => "svg", "warnings" => [], "svg_sha256" => nil },
       { "kind" => "svg", "warnings" => [], "svg_sha256" => "A" * 64 },
       { "kind" => "svg", "warnings" => [], "svg_sha256" => "a" * 63 },
       { "kind" => "svg", "warnings" => [], "unexpected" => true },
       { "kind" => "unreadable", "warnings" => [], "exception" => { "class" => "Emfsvg::ParseError" } },
       resource].each do |bad|
        allow(adapter).to receive(:inputs).and_return([inputs.first.merge("expected_outcome" => bad), inputs.last])
        expect(runner).not_to receive(:run)
        expect { run_caller.call }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /incomplete expected outcome/)
      end
    end

    context "with no historical SVG digest" do
      let(:outcome) { { "kind" => "svg", "warnings" => ["first warning\n", "second warning\n"] } }

      it "checks every bounded sample and preserves the baseline with exact warning contracts" do
        before = File.binread(@baseline)
        expect(run_caller.call.fetch("samples").size).to eq(6)
        expect(File.binread(@baseline)).to eq(before)
      end

      it "rejects warning order drift before starting children" do
        reordered = outcome.merge("warnings" => outcome.fetch("warnings").reverse)
        changed = inputs.first.merge("expected_outcome" => reordered)
        allow(adapter).to receive(:inputs).and_return([changed, inputs.last])
        expect(runner).not_to receive(:run)
        expect { run_caller.call }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /selection drift/)
      end
    end

    context "with independently reviewed outcomes beside the manifest" do
      let(:ledger_path) { File.join(@directory, "reviewed_corrupt_outcomes.json") }
      let(:ledger) do
        YAML.safe_load_file(@manifest).fetch("corrupted").to_h do |entry|
          [entry.fetch("name"), { "reviewed" => true, "source" => entry.fetch("source"),
                                  "expected_outcome" => outcome,
                                  "evidence" => [{ "kind" => "requirement", "reference" => "synthetic contract" },
                                                 { "kind" => "reference", "reference" => "synthetic source proof" }] }]
        end
      end

      before { File.write(ledger_path, JSON.generate(ledger)) }

      it "uses reviewed expectations without rewriting the pinned manifest" do
        manifest = YAML.safe_load_file(@manifest)
        manifest.fetch("corrupted").each { |entry| entry["expected_outcome"] = nil }
        File.write(@manifest, YAML.dump(manifest))
        before = File.binread(@manifest)
        expect(run_caller.call.fetch("samples").size).to eq(6)
        expect(File.binread(@manifest)).to eq(before)
      end

      it "rejects source identity drift and incomplete ledgers before child execution" do
        altered = JSON.parse(JSON.generate(ledger))
        altered.values.first.fetch("source")["sha256"] = "f" * 64
        [altered, ledger.reject { |name, _| name == ledger.keys.first }].each do |bad|
          File.write(ledger_path, JSON.generate(bad))
          expect(runner).not_to receive(:run)
          expect { run_caller.call }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /reviewed corrupt outcomes/)
        end
      end

      it "rejects invalid JSON and manifest disagreement without falling back" do
        changed = YAML.safe_load_file(@manifest)
        changed.fetch("corrupted").first["expected_outcome"] = outcome.merge("warnings" => ["changed\n"])
        File.write(@manifest, YAML.dump(changed))
        expect(runner).not_to receive(:run)
        expect { run_caller.call }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /outcome drift/)
        File.write(ledger_path, "{")
        expect { run_caller.call }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /invalid reviewed/)
      end
    end

    it "rejects unresolved manifest outcomes before child execution" do
      manifest = YAML.safe_load_file(@manifest)
      manifest.fetch("corrupted").first["expected_outcome"] = nil
      File.write(@manifest, YAML.dump(manifest))
      expect(runner).not_to receive(:run)
      expect { run_caller.call }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /incomplete pinned input/)
    end

    it "rejects a fresh measurement above the stored ceiling" do
      allow(runner).to receive(:run).and_return(calibration_report.merge(elapsed_seconds: 4))
      expect { run_caller.call }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /exceeds stored ceiling/)
    end

    it "rejects a breached child with its corrupt basename" do
      allow(runner).to receive(:run).and_return(calibration_report.merge(success: false, breach: :rss))
      expect { run_caller.call }.to raise_error(Emfsvg::ResourceCalibration::Rejected,
                                                /unsafe child outcome for one.emf/)
    end

    it "propagates strict adapter rejection instead of translating backend errors" do
      allow(adapter).to receive(:validate_report!).and_raise(Emfsvg::ResourceCalibration::Rejected, "warning mismatch")
      expect { run_caller.call }.to raise_error(Emfsvg::ResourceCalibration::Rejected, "warning mismatch")
    end

    it "rejects baseline modification during a check" do
      allow(runner).to receive(:run) do
        File.binwrite(@baseline, "unexpected baseline mutation")
        calibration_report
      end
      expect { run_caller.call }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /modified baseline/)
    end

    it "rejects a child that invokes the forbidden reference sentinel" do
      allow(runner).to receive(:run) do |options|
        system(RbConfig.ruby, options.fetch(:command).fetch(3), out: File::NULL, err: File::NULL)
        calibration_report
      end
      expect { run_caller.call }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /sentinel.*invoked/)
    end
  end
end
