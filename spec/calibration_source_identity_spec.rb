# frozen_string_literal: true

require "spec_helper"
require "stringio"
require_relative "../scripts/support/calibration_source_identity"
require_relative "../scripts/support/resource_calibration"

RSpec.describe Emfsvg::ResourceCalibration::SourceIdentity do
  include Emfsvg::SpecSupport::ResourceCalibrationFixture

  before do
    @directory = Dir.mktmpdir
    calibration_source_repository(@directory)
  end

  after { FileUtils.remove_entry(@directory) }

  it "checks an unchanged baseline after its commit while recording the actual check revision" do
    path = File.join(@directory, "spec/fixtures/baseline.yml")
    adapter = calibration_adapter
    allow(adapter).to receive(:snapshot) { calibration_provenance.merge(described_class.snapshot(root: @directory)) }
    runner = Emfsvg::SpecSupport::ResourceCalibrationFixture::Runner.new(calibration_report)
    session = Emfsvg::ResourceCalibration::Session.new(adapter: adapter, caps: calibration_caps, runner: runner)
    generated = session.execute(mode: "generate", path: path, output: StringIO.new)
    bytes = File.binread(path)
    calibration_git(@directory, "add", ".")
    calibration_git(@directory, "commit", "-qm", "Reviewed baseline")
    checked = session.execute(mode: "check", path: path, output: StringIO.new)
    expect(checked.dig("provenance", "emfsvg_revision")).to eq(calibration_git(@directory, "rev-parse", "HEAD"))
    expect(checked.dig("provenance", "emfsvg_revision")).not_to eq(generated.dig("provenance", "emfsvg_revision"))
    expect(checked.dig("provenance", "emfsvg_source_sha256")).to eq(generated.dig("provenance", "emfsvg_source_sha256"))
    expect(File.binread(path)).to eq(bytes)

    File.write(File.join(@directory, "lib/implementation.rb"), "dirty changed implementation")
    expect(runner).not_to receive(:run)
    expect { session.execute(mode: "check", path: path, output: StringIO.new) }
      .to raise_error(Emfsvg::ResourceCalibration::Rejected, /drift before execution/)
    expect(File.binread(path)).to eq(bytes)
  end

  it "fingerprints dirty additions, deletions, dependencies and runner support but excludes prose and evidence" do
    original = described_class.snapshot(root: @directory)
    %w[README.adoc scripts/notes.md spec/fixtures/baseline.yml].each do |name|
      FileUtils.mkdir_p(File.dirname(File.join(@directory, name)))
      File.write(File.join(@directory, name), "reviewed evidence")
    end
    expect(described_class.snapshot(root: @directory)).to eq(original)
    %w[lib/new.rb scripts/child.rb spec/support/runner.rb Gemfile.lock].each do |name|
      path = File.join(@directory, name)
      previous = File.file?(path) ? File.binread(path) : nil
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "changed executable input")
      expect(described_class.snapshot(root: @directory).fetch("emfsvg_source_sha256"))
        .not_to eq(original.fetch("emfsvg_source_sha256"))
      previous ? File.binwrite(path, previous) : File.delete(path)
    end
    File.delete(File.join(@directory, "lib/implementation.rb"))
    expect(described_class.snapshot(root: @directory).fetch("emfsvg_source_sha256"))
      .not_to eq(original.fetch("emfsvg_source_sha256"))
  end
end
