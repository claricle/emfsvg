# frozen_string_literal: true

require "spec_helper"
require_relative "../scripts/support/calibration_production_adapter"

RSpec.describe Emfsvg::ResourceCalibration::ProductionAdapter do
  include Emfsvg::SpecSupport::CalibrationProductionFixture

  let(:bytes) { Emfsvg.from_svg('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="2" height="2"/></svg>') }

  before do
    unless ENV["EMF_NATIVE_LIBRARY"]
      skip "requires explicitly pinned EMF_NATIVE_LIBRARY for real native-selected auto observations"
    end
  end

  it "validates exact public SVG bytes, empty warnings, runtime and real native-selected auto observations" do
    Dir.mktmpdir do |directory|
      input = production_input(directory, "valid.emf", bytes, production_svg_outcome(bytes))
      adapter = production_adapter(directory, [input])
      report = production_report(adapter, input)
      observation = JSON.parse(report.fetch(:stdout))
      expect(observation.fetch("selection_before")).to include("selected" => "Emf::Native::Adapter",
                                                               "public_contract" => false)
      expect(adapter.validate_report!(input, report)).to eq(
        "input_bytes" => bytes.bytesize, "output_bytes" => Emfsvg.from_bytes(bytes).bytesize,
        "warnings" => [], "exception" => nil
      )
    end
  end

  it "validates the exact physical skipped warning and bounded valid SVG" do
    header_size = bytes.unpack1("V", offset: 4)
    malformed = bytes.byteslice(0, header_size) + [27, 20].pack("V2")
    warning = "emfsvg: skipped EMF records: index=1,type=EMR_MOVETOEX,code=27,offset=#{header_size}\n"
    expected = nil
    expect { expected = production_svg_outcome(malformed, warnings: [warning]) }.to output(warning).to_stderr
    Dir.mktmpdir do |directory|
      input = production_input(directory, "skipped.emf", malformed, expected)
      adapter = production_adapter(directory, [input])
      expect(adapter.validate_report!(input, production_report(adapter, input)).fetch("warnings")).to eq([warning])
    end
  end

  it "validates a real unreadable conversion without partial SVG" do
    Dir.mktmpdir do |directory|
      invalid = "unreadable bytes"
      input = production_input(directory, "unreadable.emf", invalid, production_failure_outcome(invalid, "unreadable"))
      adapter = production_adapter(directory, [input])
      expect(adapter.validate_report!(input, production_report(adapter, input))).to include(
        "output_bytes" => 0, "exception" => hash_including("class" => "Emfsvg::ParseError")
      )
    end
  end

  it "validates actual upstream admission metadata and cause with a test-only lowered real parser limit" do
    wmf = [1, 9, 0x300, 12, 0, 3, 0].pack("vvvVvVv") + [3, 0].pack("Vv")
    stub_const("Emf::Wmf::Binary::MAX_INPUT_BYTES", wmf.bytesize - 1)
    Dir.mktmpdir do |directory|
      preload = File.join(directory, "test_limit.rb")
      File.write(preload, "require 'emf'; Emf::Wmf::Binary.send(:remove_const, :MAX_INPUT_BYTES); " \
                          "Emf::Wmf::Binary.const_set(:MAX_INPUT_BYTES, #{wmf.bytesize - 1})\n")
      input = production_input(directory, "resource.wmf", wmf, production_failure_outcome(wmf, "resource"))
      adapter = production_adapter(directory, [input])
      result = adapter.validate_report!(input, production_report(adapter, input, preload: preload))
      expect(result.fetch("exception")).to include("resource" => "input_bytes", "limit" => wmf.bytesize - 1,
                                                   "actual" => wmf.bytesize)
      expect(result.dig("exception", "cause", "class")).to eq("Emf::ResourceLimitError")
    end
  end

  it "preserves an actual downstream admission refusal without inventing an upstream cause" do
    stub_const("Emf::Emr::Parser::MAX_INPUT_BYTES", bytes.bytesize - 1)
    Dir.mktmpdir do |directory|
      preload = File.join(directory, "test_local_limit.rb")
      File.write(preload, "require 'emf'; Emf::Emr::Parser.send(:remove_const, :MAX_INPUT_BYTES); " \
                          "Emf::Emr::Parser.const_set(:MAX_INPUT_BYTES, #{bytes.bytesize - 1})\n")
      input = production_input(directory, "local-resource.emf", bytes, production_failure_outcome(bytes, "resource"))
      adapter = production_adapter(directory, [input])
      report = production_report(adapter, input, preload: preload)
      result = adapter.validate_report!(input, report)
      expect(result.dig("exception", "cause")).to be_nil
      expect(result.dig("exception", "actual")).to eq(bytes.bytesize)
      value = JSON.parse(report.fetch(:stdout))
      value.fetch("exception")["cause"] = { "class" => "Emf::ParseError" }
      expect do
        adapter.validate_report!(input, report.merge(stdout: JSON.generate(value)))
      end.to raise_error(Emfsvg::ResourceCalibration::Rejected, /exception mismatch/)
    end
  end

  it "rejects input drift before execution and after conversion" do
    Dir.mktmpdir do |directory|
      input = production_input(directory, "valid.emf", bytes, production_svg_outcome(bytes))
      adapter = production_adapter(directory, [input])
      report = production_report(adapter, input)
      File.binwrite(File.join(directory, input.fetch("name")), "changed")
      expect { adapter.command(input) }.to raise_error(Emfsvg::ResourceCalibration::Rejected, /digest drift/)
      expect do
        adapter.validate_report!(input, report)
      end.to raise_error(Emfsvg::ResourceCalibration::Rejected, /digest drift/)
    end
  end

  it "rejects warning, SVG, runtime, backend fallback, partial output and unexpected backend error reports" do
    Dir.mktmpdir do |directory|
      input = production_input(directory, "valid.emf", bytes, production_svg_outcome(bytes))
      adapter = production_adapter(directory, [input])
      report = production_report(adapter, input)
      value = JSON.parse(report.fetch(:stdout))
      changes = [{ "warnings" => ["unexpected\n"] }, { "svg" => "<svg/>" }, { "runtime" => {} },
                 { "selection_after" => { "selected" => "Emf::Backend::Ruby" } },
                 { "exception" => { "class" => "Emf::Native::Unavailable", "message" => "backend failed" } }]
      changes.each do |change|
        invalid = report.merge(stdout: JSON.generate(value.merge(change)))
        expect { adapter.validate_report!(input, invalid) }.to raise_error(Emfsvg::ResourceCalibration::Rejected)
      end
      expect do
        adapter.validate_report!(input, report.merge(stderr: "native failure"))
      end.to raise_error(Emfsvg::ResourceCalibration::Rejected)
    end
  end

  it "rejects a real auto fallback with an unloadable pinned artifact" do
    Dir.mktmpdir do |directory|
      input = production_input(directory, "valid.emf", bytes, production_svg_outcome(bytes))
      artifact = File.join(directory, "unloadable.dylib")
      File.write(artifact, "not a native library")
      adapter = production_adapter(directory, [input], library: artifact)
      report = production_report(adapter, input)
      expect(JSON.parse(report.fetch(:stdout)).dig("selection_after", "selected")).to eq("Emf::Backend::Ruby")
      expect { adapter.validate_report!(input, report) }.to raise_error(
        Emfsvg::ResourceCalibration::Rejected, /native-selected auto observation failed/
      )
    end
  end

  it "rejects actual native startup stderr until the upstream Fiddle packaging warning is resolved" do
    Dir.mktmpdir do |directory|
      input = production_input(directory, "valid.emf", bytes, production_svg_outcome(bytes))
      adapter = production_adapter(directory, [input])
      report = production_report(adapter, input)
      # The specific warning belongs to Ruby 3.4; future runtimes may resolve it.
      if report.fetch(:stderr).empty?
        expect(adapter.validate_report!(input, report).fetch("exception")).to be_nil
      else
        expect(report.fetch(:stderr)).to include("fiddle was loaded from the standard library")
        expect { adapter.validate_report!(input, report) }.to raise_error(
          Emfsvg::ResourceCalibration::Rejected, "unexpected child stderr"
        )
      end
    end
  end

  it "keeps the real prerequisite gate rejecting even though an adapter core exists" do
    manifest = File.expand_path("fixtures/parity_manifest.yml", __dir__)
    expect do
      Emfsvg::ResourceCalibration::Prerequisites.verify!(manifest, "unused")
    end.to raise_error(Emfsvg::ResourceCalibration::Rejected, /Public calibration contract unavailable/)
  end
end
