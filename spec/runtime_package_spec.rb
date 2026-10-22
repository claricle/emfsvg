# frozen_string_literal: true

require "spec_helper"
require_relative "../scripts/check_runtime_package"

RSpec.describe Emfsvg::RuntimePackageCheck do
  include Emfsvg::SpecSupport::RuntimePackageFixture

  it "reports the complete verified archive and runtime dependency graph" do
    with_runtime_package(dependencies: [["bigdecimal", ">= 0"]]) do |path|
      result = described_class.new(path).call

      expect(result.fetch("sha256")).to eq(Digest::SHA256.file(path).hexdigest)
      expect(result.fetch("files")).to contain_exactly(
        "lib/emfsvg.rb", "lib/emfsvg/error.rb", "lib/emfsvg/version.rb", "exe/emfsvg", "README.adoc", "LICENSE.txt"
      )
      expected_version = Gem.loaded_specs.fetch("bigdecimal").version.to_s
      expect(result.fetch("runtime_dependencies")).to eq("bigdecimal" => expected_version)
    end
  end

  it "rejects compatibility helpers even if stored under lib" do
    with_runtime_package(extra_files: ["lib/emfsvg/compat.rb"]) do |path|
      expect { described_class.new(path).call }.to raise_error(described_class::Error, /Unexpected.*compat.rb/)
    end
  end

  it "rejects corpus files outside the runtime allowlist" do
    with_runtime_package(extra_files: ["spec/fixtures/emf/example.emf"]) do |path|
      expect { described_class.new(path).call }.to raise_error(described_class::Error, /Unexpected.*example.emf/)
    end
  end

  it "rejects native C reference artifacts" do
    with_runtime_package(extra_files: ["lib/libemf2svg.dylib"]) do |path|
      expect { described_class.new(path).call }.to raise_error(described_class::Error, /Unexpected.*libemf2svg/)
    end
  end

  it "rejects reference dependencies before attempting to resolve them" do
    with_runtime_package(dependencies: [["libemf2svg", ">= 0"]]) do |path|
      expect { described_class.new(path).call }.to raise_error(described_class::Error, /Forbidden runtime.*libemf2svg/)
    end
  end

  it "fails clearly when the archive cannot be verified" do
    Dir.mktmpdir("invalid-runtime-package") do |directory|
      path = File.join(directory, "invalid.gem")
      File.write(path, "not a gem")

      expect { described_class.new(path).call }.to raise_error(described_class::Error, /Cannot verify package/)
    end
  end

  it "fails clearly when a runtime dependency is unavailable" do
    with_runtime_package(dependencies: [["emfsvg_missing_package_fixture", "= 0.0.0"]]) do |path|
      expect do
        described_class.new(path).call
      end.to raise_error(described_class::Error,
                         /Cannot verify package.*emfsvg_missing_package_fixture/)
    end
  end
end
