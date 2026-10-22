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
    manifest.tap do |data|
      provenance = data.fetch("provenance")
      provenance.fetch("runtime").merge!(
        "status" => "qualified", "source_revision" => "a" * 40, "package_sha256" => "b" * 64
      )
      provenance.fetch("upstream_contracts").each_value do |contract|
        contract.merge!("issue" => "https://github.com/claricle/emf/issues/15", "landed_revision" => "c" * 40)
      end
      provenance.fetch("native_library").merge!(
        "status" => "qualified", "source_revision" => "d" * 40, "artifact_sha256" => "e" * 64, "abi" => "emf-1"
      )
      provenance.fetch("c_reference").merge!("status" => "verified", "source_revision" => "f" * 40)
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

  it "fails closed for the recorded historical provenance gaps" do
    errors = described_class.new.errors.join("\n")
    expect(errors).to include(
      "runtime.status", "runtime.source_revision", "runtime.package_sha256",
      "model.landed_revision", "diagnostics.issue", "resources.issue",
      "native_library.status", "native_library.artifact_sha256", "native_library.abi",
      "c_reference.status", "c_reference.source_revision"
    )
  end
end
