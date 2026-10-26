# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::ReleasedNativeArchive do
  include Emfsvg::SpecSupport::ReleasedNativeArchiveFixture

  around do |example|
    Dir.mktmpdir("released-native-spec-") do |directory|
      @directory = directory
      @manifest_path = File.join(directory, "manifest.yml")
      @library = File.join(directory, "exported.so")
      @provenance = File.join(directory, "exported.json")
      @manifest = release_manifest
      example.run
    end
  end

  it "extracts the exact reviewed registry library and calibration attestation" do
    archive = build_native_archive
    expect(described_class.extract!(@manifest_path, archive, @library, @provenance)).to eq("emf-9.8.7-x86_64-linux-gnu")
    expect(File.binread(@library)).to eq("native fixture bytes")
    expect(JSON.parse(File.read(@provenance))).to eq(
      @manifest.fetch("provenance").fetch("native_library").slice("artifact_sha256", "source_revision", "abi")
    )
  end

  it "rejects package byte drift before creating either output" do
    archive = build_native_archive
    File.open(archive, "a") { |file| file.write("drift") }
    expect { described_class.extract!(@manifest_path, archive, @library, @provenance) }
      .to raise_error(Emfsvg::ReleasedQualification::Rejected, /SHA mismatch/)
    expect(File.exist?(@library)).to be(false)
    expect(File.exist?(@provenance)).to be(false)
  end

  it "rejects wrong platform, stale revision, payload hash and ABI without replacing outputs" do
    [{ gem_platform: "aarch64-linux-gnu" }, { provenance: { "revision" => "0" * 40 } },
     { provenance: { "library_sha256" => "0" * 64 } }, { platform: { "abi_version" => 2 } }].each do |changes|
      archive = build_native_archive(changes)
      File.write(@library, "preserved library")
      File.write(@provenance, "preserved provenance")
      expect { described_class.extract!(@manifest_path, archive, @library, @provenance) }
        .to raise_error(Emfsvg::ReleasedQualification::Rejected, /mismatch/)
      expect(File.read(@library)).to eq("preserved library")
      expect(File.read(@provenance)).to eq("preserved provenance")
    end
  end
end
