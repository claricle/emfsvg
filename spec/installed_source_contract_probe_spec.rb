# frozen_string_literal: true

require "tmpdir"
require_relative "support/installed_source_contract_fixture"
require_relative "../scripts/support/installed_source_contract_probe"
require_relative "support/installed_resource_probe_fixture"

RSpec.describe Emfsvg::InstalledSourceContractProbe do
  include InstalledSourceContractFixture

  around do |example|
    previous = ENV.delete("EMF_NATIVE_LIBRARY")
    example.run
  ensure
    ENV["EMF_NATIVE_LIBRARY"] = previous if previous
  end

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

  context "when checking the installed wrapper's resource decoder" do
    let(:failure) { Emf::ResourceLimitError.new(resource: :input_bytes, limit: 87, actual: 88) }
    let(:freed) { [] }
    let(:loader) { InstalledResourceProbeFixture::Loader.new(failure, 42, freed) }

    it "accepts exact typed metadata and frees a returned handle on error" do
      expect { loader.verify_input_limit }.not_to raise_error
      expect(freed).to eq([[:emf_document_free, 42]])
    end

    it "rejects stale native limit metadata while freeing the handle" do
      loader.failure = Emf::ResourceLimitError.new(resource: :input_bytes, limit: 86, actual: 88)
      expect { loader.verify_input_limit }.to raise_error("native resource metadata mismatch")
      expect(freed).to eq([[:emf_document_free, 42]])
    end

    it "rejects an unenforced limit and frees the successful document" do
      loader.failure = nil
      expect { loader.verify_input_limit }.to raise_error("native resource limit was not enforced")
      expect(freed).to eq([[:emf_document_free, 42]])
    end

    it "preserves unrelated failures and frees the document" do
      loader.failure = RuntimeError.new("invalid native input")
      expect { loader.verify_input_limit }.to raise_error(RuntimeError, "invalid native input")
      expect(freed).to eq([[:emf_document_free, 42]])
    end

    it "does not free a null document handle" do
      loader.handle = 0
      expect { loader.verify_input_limit }.not_to raise_error
      expect(freed).to be_empty
    end

    it "yields a successful document and frees it after normal completion" do
      loader.failure = nil
      expect { |block| loader.document_with_limits("bytes", nil, &block) }.to yield_with_args(42)
      expect(freed).to eq([[:emf_document_free, 42]])
    end
  end
end
