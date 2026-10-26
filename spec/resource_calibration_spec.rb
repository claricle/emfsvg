# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "tmpdir"
require_relative "../scripts/calibrate_resource_limits"

RSpec.describe Emfsvg::ResourceCalibration do
  include Emfsvg::SpecSupport::ResourceCalibrationFixture

  it "derives upward-rounded wall, RSS and address-space ceilings from all three measurements" do
    document = calibration_document
    expect(document.fetch("derived_limits")).to eq("timeout_seconds" => 3, "rss_cap_mib" => 67, "as_cap_mib" => 137)
  end

  it "runs each input three times in sequence through the authoritative bounded runner" do
    runner = Emfsvg::SpecSupport::ResourceCalibrationFixture::Runner.new
    %w[first.emf second.emf].each do |name|
      3.times do
        expected = hash_including(basename: name, authoritative: true, timeout_seconds: 100,
                                  rss_cap_mib: 1024, as_cap_mib: 2048)
        expect(runner).to receive(:run).with(expected).ordered.and_return(calibration_report)
      end
    end
    adapter = calibration_adapter(%w[first.emf second.emf].map { |name| calibration_input(name) })
    expect(described_class::Session.new(adapter: adapter, caps: calibration_caps,
                                        runner: runner).collect.fetch("samples").size).to eq(6)
  end

  it "records the bounded runner mechanism with the same string keys as pinned provenance" do
    report = calibration_report.merge(mechanism: calibration_report.fetch(:mechanism).transform_keys(&:to_sym))
    runner = Emfsvg::SpecSupport::ResourceCalibrationFixture::Runner.new(report)
    document = described_class::Session.new(adapter: calibration_adapter, caps: calibration_caps,
                                            runner: runner).collect

    expect(document.fetch("samples").map { |sample| sample.fetch("mechanism") })
      .to eq([calibration_provenance.fetch("enforcement")] * 3)
    expect(described_class::Baseline.validate!(document)).to eq(document)
    changed = Marshal.load(Marshal.dump(document))
    changed.fetch("samples").first.fetch("mechanism")["address_space"] = "unsupported"
    expect { described_class::Baseline.validate!(changed) }.to raise_error(described_class::Rejected, /child outcome/)
  end

  it "rejects missing measurements, unsafe results, and derived ceilings reaching outer caps" do
    sample = calibration_document.fetch("samples").first
    [sample.merge("as_peak_kib" => nil), sample.merge("safe" => false)].each do |invalid|
      expect { described_class::Limits.derive([invalid], calibration_caps) }.to raise_error(described_class::Rejected)
    end
    expect do
      described_class::Limits.derive([sample], calibration_caps.merge("timeout_seconds" => 3))
    end.to raise_error(described_class::Rejected, /reaches/)
  end

  it "rejects process failures before accepting any conversion report" do
    adapter = calibration_adapter
    runner = Emfsvg::SpecSupport::ResourceCalibrationFixture::Runner.new(
      calibration_report.merge(success: false, signal: 9)
    )
    expect(adapter).not_to receive(:validate_report!)
    expect do
      described_class::Session.new(adapter: adapter, caps: calibration_caps, runner: runner).collect
    end.to raise_error(described_class::Rejected, /unsafe child/)
  end

  it "rejects input and provenance drift across a run" do
    adapter = calibration_adapter
    allow(adapter).to receive(:snapshot).and_return(calibration_provenance,
                                                    calibration_provenance.merge("emfsvg_revision" => "0" * 40))
    runner = Emfsvg::SpecSupport::ResourceCalibrationFixture::Runner.new(calibration_report)
    expect do
      described_class::Session.new(adapter: adapter, caps: calibration_caps, runner: runner).collect
    end.to raise_error(described_class::Rejected, /changed/)
  end

  it "requires conversion-contract validation of warnings and typed errors before recording a sample" do
    adapter = calibration_adapter
    report = calibration_report.merge(stdout: "unexpected warning or parser failure", stderr: "native diagnostics")
    runner = Emfsvg::SpecSupport::ResourceCalibrationFixture::Runner.new(report)
    expect(adapter).to receive(:validate_report!).with(calibration_input, report)
                                                 .and_raise(described_class::Rejected, "unexpected public outcome")
    expect do
      described_class::Session.new(adapter: adapter, caps: calibration_caps, runner: runner).collect
    end.to raise_error(described_class::Rejected, /unexpected public outcome/)
  end

  it "does not treat complete recorded metadata as proof of missing public contracts" do
    provenance = Struct.new(:errors).new([])
    allow(ParityProvenance).to receive(:new).and_return(provenance)
    expect do
      described_class::Prerequisites.verify!(ParityProvenance::DEFAULT_MANIFEST, "/unread-corpus")
    end.to raise_error(described_class::Rejected, /Public calibration contract unavailable/)
  end

  it "rejects schema, sample coverage and derived-limit tampering" do
    document = calibration_document
    changes = [{ "schema_version" => 2 }, { "samples" => document.fetch("samples").take(2) },
               { "derived_limits" => document.fetch("derived_limits").merge("rss_cap_mib" => 1) }]
    changes.each do |change|
      expect { described_class::Baseline.validate!(document.merge(change)) }.to raise_error(described_class::Rejected)
    end
  end

  it "writes atomically and preserves an existing artifact when serialization fails" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "baseline.yml")
      File.write(path, "previous")
      allow(YAML).to receive(:dump).and_raise(IOError, "synthetic write failure")
      expect { described_class::Baseline.write!(path, calibration_document) }.to raise_error(IOError)
      expect(File.read(path)).to eq("previous")
      expect(Dir.children(directory)).to eq(["baseline.yml"])
    end
  end

  it "round trips the versioned baseline and checks without modifying it" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "baseline.yml")
      document = calibration_document
      described_class::Baseline.write!(path, document)
      before = File.binread(path)
      expect(described_class::Baseline.check!(YAML.safe_load_file(path), document)).to eq(document)
      changed = Marshal.load(Marshal.dump(document))
      changed.fetch("samples").first["output_bytes"] += 1
      expect { described_class::Baseline.check!(document, changed) }.to raise_error(described_class::Rejected, /drift/)
      expect(File.binread(path)).to eq(before)
    end
  end

  it "refuses both production modes before reading any corpus or touching the baseline" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "baseline.yml")
      File.write(path, "untouched")
      manifest = YAML.safe_load_file(calibration_arguments("generate", path).fetch(2))
      manifest.fetch("provenance").fetch("runtime")["status"] = "unqualified"
      manifest_path = File.join(directory, "manifest.yml")
      File.write(manifest_path, YAML.dump(manifest))
      expect(Emfsvg::SpecSupport::BoundedConversion).not_to receive(:run)
      %w[generate check].each do |mode|
        errors = StringIO.new
        arguments = calibration_arguments(mode, path)
        arguments[arguments.index("--manifest") + 1] = manifest_path
        expect(described_class::Command.run(arguments, error_output: errors)).to eq(1)
        expect(errors.string).to include("Public calibration contract unavailable", "unqualified")
      end
      expect(File.read(path)).to eq("untouched")
    end
  end

  it "requires every outer cap and rejects trailing arguments" do
    arguments = calibration_arguments("generate", "/unused")
    arguments.slice!(arguments.index("--outer-as-cap-mib"), 2)
    errors = StringIO.new
    expect(described_class::Command.run(arguments, error_output: errors)).to eq(1)
    expect(errors.string).to include("explicit outer caps")
    expect do
      described_class::Command.parse(calibration_arguments("generate", "/unused") + ["extra"])
    end.to raise_error(described_class::Rejected, /unexpected arguments/)
  end

  it "accepts varying measurements within stored ceilings and rejects an actual ceiling breach" do
    baseline = calibration_document
    observed = Marshal.load(Marshal.dump(baseline))
    observed.fetch("samples").first["elapsed_seconds"] = 0.75
    expect(described_class::Baseline.check!(baseline, observed)).to eq(observed)
    observed.fetch("samples").first["elapsed_seconds"] = 3.01
    expect do
      described_class::Baseline.check!(baseline, observed)
    end.to raise_error(described_class::Rejected, /stored ceiling/)
  end

  it "checks fresh measurements against stored ceilings without recalculating margins" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "baseline.yml")
      runner = Emfsvg::SpecSupport::ResourceCalibrationFixture::Runner.new(
        calibration_report.merge(elapsed_seconds: 20)
      )
      session = described_class::Session.new(adapter: calibration_adapter, caps: calibration_caps, runner: runner)
      session.execute(mode: "generate", path: path, output: StringIO.new)
      before = File.binread(path)
      allow(runner).to receive(:run).with(hash_including(timeout_seconds: 80))
                                    .and_return(calibration_report.merge(elapsed_seconds: 30))
      observed = session.execute(mode: "check", path: path, output: StringIO.new)
      expect(observed.fetch("samples").map { |sample| sample.fetch("elapsed_seconds") }).to eq([30, 30, 30])
      expect(observed.fetch("derived_limits").fetch("timeout_seconds")).to eq(80)
      expect(File.binread(path)).to eq(before)
      allow(runner).to receive(:run).and_return(calibration_report.merge(elapsed_seconds: 81))
      expect { session.execute(mode: "check", path: path, output: StringIO.new) }
        .to raise_error(described_class::Rejected, /stored ceiling/)
    end
  end

  it "rejects invalid stored schema and derivations before launching check children" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "baseline.yml")
      runner = Emfsvg::SpecSupport::ResourceCalibrationFixture::Runner.new
      expect(runner).not_to receive(:run)
      document = calibration_document
      changes = [{ "schema_version" => 2 },
                 { "derived_limits" => document.fetch("derived_limits").merge("timeout_seconds" => 4) }]
      changes.each do |change|
        File.write(path, YAML.dump(JSON.parse(JSON.generate(document.merge(change)))))
        session = described_class::Session.new(adapter: calibration_adapter, caps: calibration_caps, runner: runner)
        expect { session.execute(mode: "check", path: path, output: StringIO.new) }
          .to raise_error(described_class::Rejected)
      end
    end
  end

  it "executes generate and check through a qualified adapter and enforces stored check ceilings" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "baseline.yml")
      qualification = Emfsvg::SpecSupport::ResourceCalibrationFixture::Qualification.new(calibration_adapter)
      runner = Emfsvg::SpecSupport::ResourceCalibrationFixture::Runner.new(calibration_report)
      output = StringIO.new
      arguments = calibration_arguments("generate", path)
      expect(described_class::Command.run(arguments, qualification: qualification, runner: runner,
                                                     output: output)).to eq(0)
      before = File.binread(path)
      expect(runner).to receive(:run).with(hash_including(timeout_seconds: 3, rss_cap_mib: 67, as_cap_mib: 137))
                                     .exactly(3).times.and_return(calibration_report)
      arguments = calibration_arguments("check", path)
      expect(described_class::Command.run(arguments, qualification: qualification, runner: runner,
                                                     output: output)).to eq(0)
      expect(File.binread(path)).to eq(before)
      expect(output.string).to include("1 cases, 3 repetitions, zero unsafe outcomes", "Observed samples:")
    end
  end
  it "fails closed on absent or invalid implementation identities" do
    baseline = calibration_document
    [nil, "", "a" * 40].each do |identity|
      document = Marshal.load(Marshal.dump(baseline))
      document.fetch("provenance")["emfsvg_source_sha256"] = identity
      expect { described_class::Baseline.check!(baseline, document) }.to raise_error(described_class::Rejected)
    end
    baseline.fetch("provenance").delete("emfsvg_source_sha256")
    expect { described_class::Baseline.validate!(baseline) }.to raise_error(described_class::Rejected)
  end

  it "rejects every other provenance, input and cap drift before check children" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "baseline.yml")
      baseline = calibration_document
      described_class::Baseline.write!(path, baseline)
      runner = Emfsvg::SpecSupport::ResourceCalibrationFixture::Runner.new(calibration_report)
      expect(runner).not_to receive(:run)
      baseline.fetch("provenance").each_key do |key|
        next if key == "emfsvg_revision"

        adapter = calibration_adapter
        changed = Marshal.load(Marshal.dump(calibration_provenance))
        changed[key] = changed[key].is_a?(Hash) ? changed[key].transform_values { "drift" } : "f" * 64
        adapter.snapshot = changed
        session = described_class::Session.new(adapter: adapter, caps: calibration_caps, runner: runner)
        expect { session.execute(mode: "check", path: path, output: StringIO.new) }
          .to raise_error(described_class::Rejected)
        expect { described_class::Baseline.check!(baseline, baseline.merge("provenance" => changed)) }
          .to raise_error(described_class::Rejected)
      end
      [calibration_adapter([calibration_input("changed.emf")]), calibration_adapter].each_with_index do |adapter, index|
        caps = index.zero? ? calibration_caps : calibration_caps.merge("timeout_seconds" => 101)
        session = described_class::Session.new(adapter: adapter, caps: caps, runner: runner)
        expect { session.execute(mode: "check", path: path, output: StringIO.new) }
          .to raise_error(described_class::Rejected, /drift before execution/)
      end
    end
  end
end
