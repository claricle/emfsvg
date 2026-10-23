# frozen_string_literal: true

require "spec_helper"
require_relative "../scripts/support/calibration_production_adapter"

RSpec.describe Emfsvg::ResourceCalibration::ProductionAdapter do
  include Emfsvg::SpecSupport::CalibrationProductionFixture

  let(:svg_digest) { "a" * 64 }
  let(:resource_exception) do
    { "class" => "Emfsvg::ResourceLimitError", "message" => "limit exceeded", "resource" => "input_bytes",
      "limit" => 10, "actual" => 11, "cause" => nil }
  end
  let(:adapter_for_outcome) do
    lambda do |directory, outcome|
      FileUtils.mkdir_p(directory)
      File.write(File.join(directory, "emf.rb"), "runtime")
      library_path = File.join(directory, "native.dylib")
      File.write(library_path, "native")
      input = production_input(directory, "input.emf", "fixture", outcome)
      production_adapter(directory, [input], library: library_path)
    end
  end

  it "rejects malformed pinned outcomes during construction" do
    valid_svg = { "kind" => "svg", "warnings" => [], "svg_sha256" => svg_digest }
    valid_unreadable = { "kind" => "unreadable", "warnings" => [],
                         "exception" => { "class" => "Emfsvg::ParseError", "message" => "invalid input", "cause" => nil } }
    malformed = [
      [valid_svg.merge("kind" => "other"), /unknown expected outcome/],
      [valid_svg.merge("warnings" => "warning"), /expected warnings/],
      [valid_svg.merge("warnings" => [nil]), /expected warnings/],
      [valid_svg.merge("unreviewed" => true), /expected outcome fields/],
      [valid_svg.dup.tap { |value| value.delete("warnings") }, /expected warnings/],
      [valid_svg.dup.tap { |value| value.delete("svg_sha256") }, /expected outcome fields/],
      [valid_svg.merge("svg_sha256" => "not-a-digest"), /SVG digest/],
      [valid_unreadable.merge("exception" => valid_unreadable.fetch("exception").merge("class" => "RuntimeError")),
       /expected exception/],
      [valid_unreadable.merge("exception" => valid_unreadable.fetch("exception").merge(
        "cause" => { "class" => "Error" }
      )), /exception cause/],
      [{ "kind" => "resource", "warnings" => [], "exception" => resource_exception.merge("limit" => -1) },
       /resource metadata/],
      [{ "kind" => "resource", "warnings" => [], "exception" => resource_exception.merge(
        "cause" => { "class" => "Emf::ResourceLimitError", "message" => "cause", "resource" => "input_bytes",
                     "limit" => 9, "actual" => 11 }
      ) }, %r{resource metadata/cause}]
    ]

    Dir.mktmpdir do |directory|
      malformed.each do |outcome, error|
        expect do
          adapter_for_outcome.call(directory, outcome)
        end.to raise_error(Emfsvg::ResourceCalibration::Rejected, error)
      end
    end
  end

  it "accepts supported pinned SVG, unreadable, and resource outcome shapes" do
    upstream_exception = resource_exception.merge(
      "cause" => { "class" => "Emf::ResourceLimitError", "message" => "limit exceeded",
                   "resource" => "input_bytes", "limit" => 10, "actual" => 11 }
    )
    outcomes = [
      { "kind" => "svg", "warnings" => [], "svg_sha256" => svg_digest },
      { "kind" => "svg", "warnings" => ["emfsvg: skipped EMF records: index=1\n"], "svg_sha256" => svg_digest },
      { "kind" => "unreadable", "warnings" => [],
        "exception" => { "class" => "Emfsvg::ParseError", "message" => "invalid input", "cause" => nil } },
      { "kind" => "resource", "warnings" => [], "exception" => resource_exception },
      { "kind" => "resource", "warnings" => [], "exception" => upstream_exception }
    ]

    Dir.mktmpdir do |directory|
      outcomes.each { |outcome| expect { adapter_for_outcome.call(directory, outcome) }.not_to raise_error }
    end
  end
end
