# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Pinned runtime dependency" do
  include Emfsvg::SpecSupport::RuntimeDependencyFixture

  it "loads the exact locked Git revision independently of the corpus checkout" do
    output, error, status = runtime_dependency_observation

    expect(status.success?).to be(true), error
    identity = JSON.parse(output)
    expect(identity.fetch("revision")).to eq(Emfsvg::SpecSupport::RuntimeDependencyFixture::RUNTIME_REVISION)
    expect(identity.fetch("remote")).to eq("https://github.com/claricle/emf.git")
    expect(identity.fetch("entry_point")).to eq(File.join(identity.fetch("gem_path"), "lib/emf.rb"))
  end

  it "fails when the lockfile selects another repository" do
    with_runtime_dependency_lock(remote: "https://example.invalid/emf.git") do |lockfile|
      _output, error, status = runtime_dependency_observation(lockfile: lockfile)

      expect(status.success?).to be(false)
      expect(error).to include("emf lock source must be https://github.com/claricle/emf.git")
    end
  end

  it "fails when the lockfile selects another revision" do
    with_runtime_dependency_lock(revision: "a" * 40) do |lockfile|
      _output, error, status = runtime_dependency_observation(lockfile: lockfile)

      expect(status.success?).to be(false)
      expect(error).to include("emf lock source must be", "full ref/revision")
    end
  end

  it "independently rejects a loaded checkout that differs from the lockfile" do
    with_runtime_dependency_lock(revision: "a" * 40) do |lockfile|
      _output, error, status = runtime_dependency_observation(lockfile: lockfile, revision: "a" * 40)

      expect(status.success?).to be(false)
      expect(error).to include("loaded emf revision", "differs from #{'a' * 40}")
    end
  end
end
