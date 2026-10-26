# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"
require "tmpdir"
require "yaml"
require_relative "../scripts/check_parity_provenance"

RSpec.describe ParityProvenance do
  let(:manifest) { YAML.safe_load_file(described_class::DEFAULT_MANIFEST) }
  let(:metadata) do
    YAML.safe_load_file(described_class::DEFAULT_MANIFEST).tap do |data|
      provenance = data.fetch("provenance")
      provenance.fetch("runtime").merge!(
        "status" => "qualified", "source" => "rubygems", "source_revision" => "a" * 40, "package_sha256" => "b" * 64
      )
      provenance.fetch("upstream_contracts").each_value do |contract|
        contract.merge!("issue" => "https://github.com/claricle/emf/issues/15", "landed_revision" => "c" * 40)
      end
      provenance.fetch("native_library").merge!(
        "status" => "qualified", "source_revision" => "d" * 40, "artifact_sha256" => "e" * 64, "abi" => "emf-1"
      )
      provenance.fetch("c_reference").merge!(
        "status" => "verified", "source_revision" => "f" * 40, "binary_sha256" => "a" * 64
      )
    end
  end
  let(:directory) { Dir.mktmpdir("parity-provenance") }
  let(:path) { File.join(directory, "manifest.yml") }
  let(:script) { File.expand_path("../scripts/check_parity_provenance.rb", __dir__) }
  let(:result) { Open3.capture3(RbConfig.ruby, script, path) }

  before { File.write(path, YAML.dump(metadata)) }
  after { FileUtils.remove_entry(directory) }

  it "accepts complete released-package metadata without claiming runtime qualification" do
    output, errors, status = result
    expect(status).to be_success
    expect(errors).to be_empty
    expect(output).to include("metadata is ready", "runtime and native qualification remain separate checks")
  end

  it "lists every missing or malformed field and exits unsuccessfully" do
    metadata.fetch("provenance").fetch("runtime").merge!("source_revision" => "abc123", "package_sha256" => "A" * 64)
    metadata.fetch("provenance").fetch("native_library")["abi"] = nil
    metadata.fetch("provenance").fetch("upstream_contracts").fetch("resources")["issue"] = "https://example.com/issues/15"
    File.write(path, YAML.dump(metadata))

    output, errors, status = result
    expect(status.exitstatus).to eq(1)
    expect(output).to be_empty
    expect(errors).to include(
      "runtime.source_revision", "runtime.package_sha256", "native_library.abi", "resources.issue"
    )
  end

  it "rejects malformed containing blocks without crashing" do
    metadata["provenance"] = ["invalid"]
    File.write(path, YAML.dump(metadata))

    _output, errors, status = result
    expect(status.exitstatus).to eq(1)
    expect(errors).to include("runtime.source_revision", "native_library.artifact_sha256", "model.landed_revision")
  end

  it "requires every contract revision independently" do
    metadata.fetch("provenance").fetch("upstream_contracts").each_value { |contract| contract["landed_revision"] = nil }
    File.write(path, YAML.dump(metadata))

    expect(described_class.new(path).errors.grep(/landed_revision/).length).to eq(3)
  end

  it "rejects uppercase or nonhex revisions and short checksums" do
    provenance = metadata.fetch("provenance")
    provenance.fetch("runtime")["source_revision"] = "A" * 40
    provenance.fetch("native_library")["source_revision"] = "g" * 40
    provenance.fetch("native_library")["artifact_sha256"] = "e" * 63
    File.write(path, YAML.dump(metadata))

    expect(described_class.new(path).errors.length).to eq(3)
  end

  it "rejects unreleased sources and fallback backend metadata" do
    provenance = metadata.fetch("provenance")
    provenance.fetch("runtime").merge!("source" => "git", "version" => "0.2.0.pre")
    provenance.fetch("production_backend")["required_selected"] = "ruby"
    File.write(path, YAML.dump(metadata))

    expect(described_class.new(path).errors.length).to eq(3)
  end

  it "rejects missing wrapper options even when the expected value is null" do
    metadata.fetch("provenance").fetch("c_reference").fetch("wrapper_options").delete("nameSpace")
    File.write(path, YAML.dump(metadata))

    expect(described_class.new(path).errors.join).to include("wrapper_options.nameSpace")
  end

  it "rejects absent or malformed C binary checksums before declaring metadata ready" do
    [nil, "", "a" * 63, "A" * 64, "g" * 64].each do |checksum|
      metadata.fetch("provenance").fetch("c_reference")["binary_sha256"] = checksum
      File.write(path, YAML.dump(metadata))

      output, errors, status = Open3.capture3(RbConfig.ruby, script, path)
      expect(status.exitstatus).to eq(1), "accepted checksum #{checksum.inspect}"
      expect(output).to be_empty
      expect(errors).to include("c_reference.binary_sha256")
    end
  end

  it "reports unsafe YAML as a setup failure" do
    File.write(path, "--- !ruby/object:Object {}\n")
    _output, errors, status = result
    expect(status.exitstatus).to eq(1)
    expect(errors).to include("could not be read")
  end

  it "reports a missing manifest as a setup failure" do
    FileUtils.rm(path)

    _output, errors, status = result
    expect(status.exitstatus).to eq(1)
    expect(errors).to include("could not be read")
  end

  it "records the exact released package selected by the lockfile" do
    runtime = manifest.fetch("provenance").fetch("runtime")
    locked = Bundler.locked_gems.specs.find { |spec| spec.name == "emf" }

    expect(locked.source).to be_a(Bundler::Source::Rubygems)
    expect(runtime).to include(
      "status" => "qualified", "source" => "rubygems", "version" => locked.version.to_s,
      "source_revision" => "327c36b49743bcb9799c20123218f0bae965f1de",
      "package_sha256" => "6b3add05605260d646ec1d732da139eb972016c6fe4547aa60846a2ac2f542fa"
    )
    expect(described_class.new.errors).to be_empty
  end

  it "records the landed model, diagnostics, and resource contracts" do
    contracts = manifest.fetch("provenance").fetch("upstream_contracts")

    expect(contracts.fetch("model")).to eq(
      "issue" => "https://github.com/claricle/emf/issues/15",
      "landed_revision" => "318b2d86c4025b5913c595c5055477124199daf9"
    )
    expect(contracts.fetch("diagnostics")).to eq(
      "issue" => "https://github.com/claricle/emf/issues/65",
      "landed_revision" => "e0491ed331dff6c5996dcbd9a269b79ffebbcc38"
    )
    expect(contracts.fetch("resources")).to eq(
      "issue" => "https://github.com/claricle/emf/issues/66",
      "landed_revision" => "e0491ed331dff6c5996dcbd9a269b79ffebbcc38"
    )
  end

  it "fails closed for remaining release and native provenance gaps" do
    provenance = metadata.fetch("provenance")
    provenance.fetch("runtime").merge!("status" => "unqualified", "source" => "git", "package_sha256" => nil)
    provenance.fetch("native_library").merge!("status" => "unqualified", "artifact_sha256" => nil, "abi" => nil)
    File.write(path, YAML.dump(metadata))

    errors = described_class.new(path).errors.join("\n")
    expect(errors).to include(
      "runtime.status", "runtime.source: expected \"rubygems\"", "runtime.package_sha256",
      "native_library.status", "native_library.artifact_sha256", "native_library.abi"
    )
    expect(errors).not_to include("runtime.source_revision", "model.landed_revision", "c_reference.",
                                  "diagnostics.landed_revision", "resources.landed_revision")
  end
end
