# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Pinned runtime dependency" do
  include Emfsvg::SpecSupport::RuntimeDependencyFixture

  it "loads the exact locked released revision independently of the corpus checkout" do
    output, error, status = runtime_dependency_observation

    expect(status.success?).to be(true), error
    identity = JSON.parse(output)
    expect(identity.fetch("revision")).to eq(Emfsvg::SpecSupport::RuntimeDependencyFixture::RUNTIME_REVISION)
    expect(identity.fetch("remote")).to eq("https://rubygems.org")
    expect(identity.fetch("entry_point")).to eq(File.join(identity.fetch("gem_path"), "lib/emf.rb"))
  end

  it "fails when the lockfile selects another repository" do
    with_runtime_dependency_lock(remote: "https://example.invalid/emf.git") do |lockfile|
      _output, error, status = runtime_dependency_observation(lockfile: lockfile, remote: Emfsvg::SpecSupport::RuntimeDependencyFixture::RUNTIME_REMOTE)

      expect(status.success?).to be(false)
      expect(error).to include("emf lock source must be https://github.com/claricle/emf.git")
    end
  end

  it "rejects a shadow entrypoint and reports the loaded and expected paths" do
    Dir.mktmpdir("shadow-runtime-dependency") do |directory|
      entrypoint = File.join(directory, "emf.rb")
      File.write(entrypoint, "# A different entrypoint on the Ruby load path.\n")

      _output, error, status = runtime_dependency_observation(load_path: directory)

      expect(status.success?).to be(false)
      expect(error).to include("emf entry point was not loaded from the pinned checkout",
                               entrypoint, File.join(Gem.loaded_specs.fetch("emf").full_gem_path, "lib/emf.rb"))
    end
  end

  it "fails when the lockfile selects another revision" do
    with_runtime_dependency_lock(revision: "a" * 40) do |lockfile|
      _output, error, status = runtime_dependency_observation(lockfile: lockfile, remote: Emfsvg::SpecSupport::RuntimeDependencyFixture::RUNTIME_REMOTE)

      expect(status.success?).to be(false)
      expect(error).to include("emf lock source must be", "full ref/revision")
    end
  end

  it "independently rejects a loaded release revision that differs from the required revision" do
    _output, error, status = runtime_dependency_observation(revision: "a" * 40)

    expect(status.success?).to be(false)
    expect(error).to include("loaded emf revision", "differs from #{'a' * 40}")
  end
end
