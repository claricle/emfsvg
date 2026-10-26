# frozen_string_literal: true

require "spec_helper"
require_relative "../scripts/qualify_source_runtime"

RSpec.describe Emfsvg::ResourceCalibration::SourceCommand do
  include Emfsvg::SpecSupport::SourceQualificationFixture

  before do
    source_qualification_fixture
    adapter = qualify_source
    qualifier = instance_double(Emfsvg::ResourceCalibration::SourceQualification, verify!: adapter)
    allow(Emfsvg::ResourceCalibration::SourceQualification).to receive(:new).and_return(qualifier)
    allow(Emfsvg::SpecSupport::BoundedConversion).to receive(:run) { |**request| @runner.run(**request) }
    @calls.clear
    @destination = File.join(@directory, "qualification.json")
  end

  after { FileUtils.remove_entry(@directory) }

  it "records three enforced repetitions of every pinned input without claiming release qualification" do
    status = described_class.run([@manifest_path, @directory, @destination], output: StringIO.new)
    expect(status).to eq(0)
    evidence = JSON.parse(File.read(@destination))
    expect(evidence).to include("scope" => "prerelease-source", "released_runtime_qualified" => false)
    expect(evidence.fetch("samples").size).to eq(90)
    expect(evidence.fetch("samples").map { |sample| sample.fetch("repetition") }.tally).to eq(1 => 30, 2 => 30, 3 => 30)
    expect(@calls).to all(include(authoritative: true))
  end

  it "refuses successful-looking children with an unknown exit status without writing evidence" do
    allow(Emfsvg::SpecSupport::BoundedConversion).to receive(:run) do |**request|
      @runner.run(**request).merge(status: :unknown)
    end
    errors = StringIO.new
    status = described_class.run([@manifest_path, @directory, @destination], error_output: errors)
    expect(status).to eq(1)
    expect(errors.string).to include("unsafe source calibration child")
    expect(File).not_to exist(@destination)
  end

  it "refuses enforcement drift between conformance and samples" do
    allow(Emfsvg::SpecSupport::BoundedConversion).to receive(:run) do |**request|
      @runner.run(**request).merge(mechanism: { rss: "ps RSS" })
    end
    errors = StringIO.new
    status = described_class.run([@manifest_path, @directory, @destination], error_output: errors)
    expect(status).to eq(1)
    expect(errors.string).to include("enforcement drift")
    expect(File).not_to exist(@destination)
  end
end
