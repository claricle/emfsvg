# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::ResourceCalibration::Qualification do
  include Emfsvg::SpecSupport::CalibrationQualificationFixture

  before { qualification_fixture(Dir.mktmpdir) }

  after { FileUtils.remove_entry(@directory) }

  it "qualifies controlled release evidence and all 30 cases on each public backend" do
    adapter = qualify
    expect(adapter).to be_a(Emfsvg::ResourceCalibration::ProductionAdapter)
    expect(adapter.inputs.size).to eq(30)
    expect(@calls.drop(1).map do |request|
      request.fetch(:command)[-4]
    end.tally).to eq("ruby" => 30, "native" => 30, "auto" => 30)
    expect(adapter.snapshot.fetch("runtime")).to eq(@manifest.dig("provenance", "runtime").slice(
                                                      "version", "package_sha256", "source_revision"
                                                    ))
    expect(@calls).to all(include(timeout_seconds: 30, rss_cap_mib: 512, as_cap_mib: 2048))
    expect(@manifest.fetch("corrupted").map { |entry| entry["expected_outcome"] }).to all(be_nil)
  end

  it "preserves the real manifest rejection before starting any child" do
    path = File.expand_path("fixtures/parity_manifest.yml", __dir__)
    expect do
      Emfsvg::ResourceCalibration::Prerequisites.verify!(path, @directory, runner: @runner)
    end.to raise_error(Emfsvg::ResourceCalibration::Rejected, /runtime.status.*unqualified/)
    expect(@calls).to be_empty
  end

  it "preserves exact issue 65 and 66 prerequisites even with otherwise qualified metadata" do
    @manifest.dig("provenance", "upstream_contracts", "diagnostics")["issue"] = "https://github.com/claricle/emf/issues/66"
    write_qualification_evidence
    expect { qualify }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /diagnostics: expected upstream issue.*65/)
    expect(@calls).to be_empty
  end

  it "rejects missing, extra, duplicated and changed corpus identities" do
    original = JSON.generate(@manifest)
    [-> { @manifest.fetch("corrupted").pop },
     -> { @manifest.fetch("corrupted") << @manifest.fetch("corrupted").first },
     -> { @manifest.fetch("fixed_sample")[1] = @manifest.fetch("fixed_sample").first },
     -> { @manifest.fetch("fixtures").first.fetch("round_trip")["sha256"] = "f" * 64 }].each do |mutate|
      @manifest = JSON.parse(original)
      mutate.call
      write_qualification_evidence
      expect { qualify }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /inventory mismatch/)
    end
    expect(@calls).to be_empty
  end

  it "requires independently reviewed source-matched complete outcomes" do
    record = @ledger.values.first
    record["reviewed"] = false
    write_qualification_evidence
    expect { qualify }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /21 independently reviewed/)
    expect(@calls).to be_empty
  end

  it "rejects a changed archive and installed runtime despite complete metadata" do
    File.write(@package_path, "tampered")
    expect { qualify }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /package SHA/)
    qualification_fixture(@directory)
    File.write(File.join(@runtime_root, "lib/emf.rb"), "tampered installed runtime")
    expect { qualify }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /installed release file/)
  end

  it "preserves bounded child refusal for unsuccessful, breached or noisy results" do
    report = { success: true, breach: nil, stderr: "", signal: nil, status: :exited, exitstatus: 0 }
    [{ success: false }, { breach: :timeout }, { stderr: "unexpected warning" },
     { signal: 9 }, { status: :running }, { exitstatus: 1 }].each do |change|
      allow(@runner).to receive(:run).and_return(report.merge(change))
      expect { qualify }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /bounded qualification child failed/)
    end
  end

  it "rejects loaded version, entrypoint and native ABI mismatches" do
    [->(value) { value["version"] = "1.2.4" },
     ->(value) { value["entrypoint"] = @native_path },
     ->(value) { value["abi"] = "2" }].each do |mutate|
      @mutate_report = ->(value, request) { mutate.call(value) if request.fetch(:basename) == "runtime-identity" }
      expect do
        qualify
      end.to raise_error(Emfsvg::ResourceCalibration::Rejected, /version mismatch|entrypoint mismatch|ABI mismatch/)
    end
  end

  it "compares native attestation with manifest pins and actual bytes" do
    File.write(@native_path, "changed native")
    expect { qualify }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /native artifact.source.ABI mismatch/)
    expect(@calls).to be_empty
    @manifest.dig("provenance", "native_library")["artifact_sha256"] = sha(@native_path)
    write_qualification_evidence
    document = JSON.parse(File.read(@native_provenance)).merge("source_revision" => "b" * 40)
    File.write(@native_provenance, JSON.generate(document))
    expect { qualify }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /native artifact.source.ABI mismatch/)
  end

  it "rejects auto fallback and backend selection that changes after conversion" do
    %w[selection_before selection_after].each do |phase|
      @mutate_report = lambda do |value, request|
        value.fetch(phase)["selected"] = "ruby" if request.fetch(:basename).start_with?("auto-")
      end
      expect { qualify }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /auto conformance identity.selection/)
    end
  end

  it "checks ordered warnings, exact valid SVG bytes and corrupt original causes on ruby and native" do
    mutations = [->(value) { value["warnings"] = ["extra warning\n"] },
                 lambda { |value|
                   value["svg"] = Emfsvg::SpecSupport::CalibrationQualificationFixture::SVG.sub("/>", "><g/></svg>")
                   value["output_bytes"] = value.fetch("svg").bytesize
                 },
                 ->(value) { value.fetch("exception").fetch("cause")["message"] = "wrong original cause" }]
    mutations.each_with_index do |mutate, index|
      @mutate_report = lambda do |value, request|
        target = index == 2 ? "native-corrupt-0.emf" : "ruby-valid-0.emf"
        mutate.call(value) if request.fetch(:basename) == target
      end
      expect do
        qualify
      end.to raise_error(Emfsvg::ResourceCalibration::Rejected, /warning mismatch|SVG digest|exception.cause/)
    end
  end

  it "rejects partial SVG on failure and refuses drift after qualification" do
    @mutate_report = lambda do |value, request|
      if request.fetch(:basename) == "native-corrupt-0.emf"
        value["svg"] =
          Emfsvg::SpecSupport::CalibrationQualificationFixture::SVG
      end
    end
    expect { qualify }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /partial SVG/)
    @mutate_report = nil
    adapter = qualify
    File.write(@lockfile, "changed lock")
    expect { adapter.snapshot }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /evidence drift/)
  end
end

RSpec.describe Emfsvg::ResourceCalibration::QualificationInventory do
  it "projects the pinned real inventory and reviewed ledger without changing manifest bytes" do
    path = File.expand_path("fixtures/parity_manifest.yml", __dir__)
    before = Digest::SHA256.file(path).hexdigest
    manifest = YAML.safe_load_file(path)
    ledger = JSON.parse(File.read(File.join(File.dirname(path), "reviewed_corrupt_outcomes.json")))
    inputs = described_class.new(manifest, ledger).inputs
    expect(inputs.size).to eq(30)
    expect(inputs.first(9).map do |input|
      input.dig("expected_outcome", "svg_sha256")
    end).to all(match(/\A[a-f0-9]{64}\z/))
    expect(inputs.drop(9).map do |input|
      input.dig("expected_outcome", "kind")
    end.tally).to eq("svg" => 19, "unreadable" => 2)
    expect(manifest.fetch("corrupted").map { |entry| entry["expected_outcome"] }).to all(be_nil)
    expect(Digest::SHA256.file(path).hexdigest).to eq(before)
  end
end
