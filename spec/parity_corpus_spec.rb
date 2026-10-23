# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::SpecSupport::ParityCorpus do
  include Emfsvg::SpecSupport::ParityInventoryFixture

  it "rejects an absent explicit corpus root" do
    expect { described_class.new(root: nil).verify! }.to raise_error(described_class::SetupError, /EMF_FIXTURE_ROOT/)
  end

  it "accepts the complete pinned inventory" do
    with_parity_inventory do |root, project, manifest, _data|
      resolver = described_class.new(root: root, project_root: project, manifest_path: manifest)
      expect(resolver.source_paths.size).to eq(208)
      expect(resolver.corrupted.size).to eq(21)
    end
  end

  {
    "duplicate basename" => ->(data) { data["fixtures"][1]["name"] = data["fixtures"][0]["name"] },
    "Invalid parity manifest" => ->(data) { data["fixtures"] = nil },
    "count" => ->(data) { data["groups"]["golden"] = 207 },
    "corpus revision" => ->(data) { data["provenance"]["corpus"]["revision"] = "0" * 40 },
    "SHA-256" => ->(data) { data["fixtures"][0]["source"]["sha256"] = "0" * 64 },
    "fixed historical sample" => ->(data) { data["fixed_sample"].reverse! },
    "aggregate_sha256" => ->(data) { data["inventories"]["aggregate_sha256"] = "0" * 64 }
  }.each do |error, mutation|
    it "rejects #{error} drift" do
      with_parity_inventory do |root, project, manifest, data|
        mutation.call(data)
        File.write(manifest, YAML.dump(data))
        resolver = described_class.new(root: root, project_root: project, manifest_path: manifest)
        expect { resolver.verify! }.to raise_error(described_class::SetupError, /#{error}/)
      end
    end
  end

  it "rejects missing, changed, and unexpected artifacts" do
    with_parity_inventory do |root, project, manifest, data|
      resolver = described_class.new(root: root, project_root: project, manifest_path: manifest)
      path = File.join(project, data.fetch("fixtures").first.fetch("golden").fetch("path"))
      bytes = File.binread(path)
      File.write(path, "changed")
      expect { resolver.verify! }.to raise_error(described_class::SetupError, /SHA-256/)
      File.delete(path)
      expect { resolver.verify! }.to raise_error(described_class::SetupError, /inventory mismatch/)
      File.binwrite(path, bytes)
      File.write(File.join(File.dirname(path), "unexpected.svg"), "extra")
      expect { resolver.verify! }.to raise_error(described_class::SetupError, /unexpected.svg/)
    end
  end

  it "rejects unexpected source files" do
    with_parity_inventory do |root, project, manifest, _data|
      File.write(File.join(root, "spec/fixtures/emf/unexpected.emf"), "extra")
      resolver = described_class.new(root: root, project_root: project, manifest_path: manifest)
      expect { resolver.verify! }.to raise_error(described_class::SetupError, /unexpected.emf/)
    end
  end
end
