# frozen_string_literal: true

require "tmpdir"
require_relative "support/installed_source_contract_fixture"
require_relative "../scripts/support/installed_source_contract_probe"

RSpec.describe Emfsvg::InstalledSourceContractProbe do
  include InstalledSourceContractFixture

  it "rejects a short expected revision before inspecting installed gems" do
    expect do
      described_class.call("/missing", "bad", "/missing/image.emf")
    end.to raise_error("expected revision must be a full lowercase Git SHA")
  end

  it "rejects a source revision mismatch from the supplied isolated gem home" do
    Dir.mktmpdir do |directory|
      home, = installed_source_fixture(directory, revision: "0" * 40)
      expect do
        described_class.call(home, InstalledSourceContractFixture::REVISION, "/missing/image.emf")
      end.to raise_error("installed emf source revision mismatch")
    end
  end

  it "rejects conflicting gem metadata and packaged provenance revisions" do
    Dir.mktmpdir do |directory|
      home, = installed_source_fixture(directory, metadata_revision: "1" * 40)
      expect do
        described_class.call(home, InstalledSourceContractFixture::REVISION, "/missing/image.emf")
      end.to raise_error("installed emf provenance revision mismatch")
    end
  end

  it "rejects explicit native library overrides" do
    previous = ENV.fetch("EMF_NATIVE_LIBRARY", nil)
    ENV["EMF_NATIVE_LIBRARY"] = "/tmp/shadow.so"
    expect do
      described_class.call("/missing", InstalledSourceContractFixture::REVISION, "/missing/image.emf")
    end.to raise_error("EMF_NATIVE_LIBRARY override is forbidden")
  ensure
    previous ? ENV["EMF_NATIVE_LIBRARY"] = previous : ENV.delete("EMF_NATIVE_LIBRARY")
  end
end
