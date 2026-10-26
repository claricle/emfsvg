# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::ResourceCalibration::SourceQualification do
  include Emfsvg::SpecSupport::SourceQualificationFixture

  before { source_qualification_fixture }
  after { FileUtils.remove_entry(@directory) }

  it "qualifies all public backends with Linux enforcement while preserving the release refusal" do
    adapter = qualify_source
    expect(@calls.drop(1).map { |request| request.fetch(:command)[-4] }.tally).to eq(
      "ruby" => 30, "native" => 30, "auto" => 30
    )
    expect(@calls).to all(include(authoritative: true))
    expect(adapter.snapshot).to include("scope" => "prerelease-source", "released_runtime_qualified" => false)
    expect(adapter.snapshot).to include(Emfsvg::ResourceCalibration::SourceIdentity.snapshot)
    expect { qualify }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /runtime.status.*unqualified/)
  end

  it "refuses non-Linux qualification before starting a child" do
    stub_const("Emfsvg::ResourceCalibration::SourceQualification::RUBY_PLATFORM", "arm64-darwin")
    expect { qualify_source }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /requires Linux/)
    expect(@calls).to be_empty
  end

  it "rejects source and native drift after successful conformance" do
    adapter = qualify_source
    File.write(File.join(@runtime_root, "lib/other.rb"), "drift")
    expect { adapter.snapshot }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /source runtime drift/)
    FileUtils.remove_entry(@directory)
    source_qualification_fixture
    adapter = qualify_source
    File.write(@native_path, "drift")
    expect { adapter.snapshot }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /native artifact/)
  end

  it "rejects a source runtime from another revision" do
    original = @mutate_report
    @mutate_report = lambda do |value, request|
      original.call(value, request)
      value["source_revision"] = "b" * 40 if request.fetch(:basename) == "source-runtime-identity"
    end
    expect { qualify_source }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /source runtime drift/)
  end
end
