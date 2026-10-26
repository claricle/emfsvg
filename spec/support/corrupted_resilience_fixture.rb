# frozen_string_literal: true

require "digest"
require "rbconfig"
require "stringio"
require "tmpdir"
require_relative "../../scripts/support/calibration_production_adapter"
require_relative "../../scripts/support/corrupt_outcome_contract"

module Emfsvg
  module SpecSupport
    # Consumes qualification; neither this caller nor its mechanics specs grant it.
    class CorruptedResilienceFixture
      Calibration = Emfsvg::ResourceCalibration

      class SentinelRunner
        def initialize(runner, sentinel, marker)
          @runner = runner
          @sentinel = sentinel
          @marker = marker
        end

        def run(command:, **options)
          bootstrap = 'ENV["EMF2SVG_REF_PATH"], ENV["EMF2SVG_REF_LIB_DIR"] = ARGV.shift(2); exec(*ARGV)'
          @runner.run(command: [RbConfig.ruby, "-e", bootstrap, @sentinel, @sentinel, *command], **options)
        ensure
          raise Calibration::Rejected, "forbidden reference sentinel invoked" if File.exist?(@marker)
        end
      end

      def self.qualification_requested?(environment = ENV)
        %w[EMF_RELEASE_PACKAGE EMF_NATIVE_LIBRARY EMF_NATIVE_PROVENANCE QUALIFICATION_MODE].any? do |key|
          environment.key?(key)
        end
      end

      def initialize(qualification: Calibration::Prerequisites, runner: BoundedConversion)
        @qualification = qualification
        @runner = runner
      end

      def run(manifest:, fixture_root:, baseline:)
        adapter = @qualification.verify!(manifest, fixture_root)
        validate_inventory!(YAML.safe_load_file(manifest), adapter.inputs,
                            File.join(File.dirname(manifest), "reviewed_corrupt_outcomes.json"))
        stored = Calibration::Baseline.validate!(YAML.safe_load_file(baseline))
        baseline_digest = Digest::SHA256.file(baseline).hexdigest
        with_sentinel do |runner|
          Calibration::Session.new(adapter: adapter, caps: stored.fetch("outer_caps"), runner: runner)
                              .execute(mode: "check", path: baseline, output: StringIO.new)
        end
      ensure
        if baseline_digest && !(File.file?(baseline) && Digest::SHA256.file(baseline).hexdigest == baseline_digest)
          raise Calibration::Rejected, "resilience check modified baseline"
        end
      end

      private

      def validate_inventory!(manifest, inputs, ledger_path)
        corrupt = manifest.fetch("corrupted")
        raise Calibration::Rejected, "no declared corrupted inputs" unless corrupt.is_a?(Array) && !corrupt.empty?

        outcomes = reviewed_outcomes(manifest, ledger_path)
        declared = corrupt.map do |entry|
          expected = outcomes ? outcomes.fetch(entry.fetch("name")) : entry.fetch("expected_outcome")
          if outcomes && entry["expected_outcome"] && entry["expected_outcome"] != expected
            raise Calibration::Rejected, "manifest and reviewed corrupt outcome drift"
          end

          input = { "name" => entry.fetch("source").fetch("path"),
                    "sha256" => entry.fetch("source").fetch("sha256"),
                    "expected_outcome" => expected }
          Calibration::Baseline.validate_input!(input)
          input
        end
        names = declared.map { |input| input.fetch("name") }
        raise Calibration::Rejected, "duplicate corrupt input identity" unless names.uniq == names

        inputs.each { |input| validate_outcome!(input.fetch("expected_outcome")) }
        declared.each do |input|
          selected = inputs.select { |candidate| candidate.fetch("name") == input.fetch("name") }
          unless selected == [input]
            raise Calibration::Rejected,
                  "corrupt input selection drift: #{input.fetch('name')}"
          end
        end
      rescue KeyError, TypeError, NoMethodError => e
        raise Calibration::Rejected, "incomplete corrupt inventory: #{e.message}"
      end

      def reviewed_outcomes(manifest, ledger_path)
        return unless File.exist?(ledger_path)

        ledger = JSON.parse(File.read(ledger_path))
        report = CorruptOutcomeContract.new(manifest: manifest, ledger: ledger).report
        unless report.fetch("cases").all? { |entry| entry.fetch("status") == "contracted" }
          raise Calibration::Rejected, "unresolved or mismatched reviewed corrupt outcomes"
        end

        report.fetch("cases").to_h do |entry|
          [entry.fetch("name"), entry.fetch("expected_outcome")]
        end
      rescue JSON::ParserError, CorruptOutcomeContract::Rejected => e
        raise Calibration::Rejected, "invalid reviewed corrupt outcomes: #{e.message}"
      end

      def validate_outcome!(outcome)
        valid = outcome.is_a?(Hash) && outcome["warnings"].is_a?(Array) &&
                outcome["warnings"].all?(String)
        raise Calibration::Rejected, "incomplete expected outcome" unless valid

        case outcome["kind"]
        when "svg"
          digest = outcome["svg_sha256"]
          fields = outcome.key?("svg_sha256") ? %w[kind svg_sha256 warnings] : %w[kind warnings]
          valid = outcome.keys.sort == fields &&
                  (!outcome.key?("svg_sha256") || (digest.is_a?(String) && ParityProvenance::SHA256.match?(digest)))
        when "unreadable", "resource"
          valid = valid_failure?(outcome)
        else
          valid = false
        end
        raise Calibration::Rejected, "incomplete expected outcome" unless valid
      end

      def valid_failure?(outcome)
        failure = outcome["exception"]
        klass = outcome["kind"] == "resource" ? "Emfsvg::ResourceLimitError" : "Emfsvg::ParseError"
        return false unless failure.is_a?(Hash) && failure["class"] == klass &&
                            failure["message"].is_a?(String) && failure.key?("cause")
        return true unless outcome["kind"] == "resource"

        failure["resource"].is_a?(String) && !failure["resource"].empty? &&
          failure["limit"].is_a?(Integer) && failure["limit"] >= 0 &&
          failure["actual"].is_a?(Integer) && failure["actual"] > failure["limit"]
      end

      def with_sentinel
        Dir.mktmpdir("emfsvg-corrupt-reference-") do |directory|
          marker = File.join(directory, "called")
          sentinel = File.join(directory, "forbidden-reference")
          File.write(sentinel, "File.write(#{marker.inspect}, \"called\")\n")
          digest = Digest::SHA256.file(sentinel).hexdigest
          begin
            yield SentinelRunner.new(@runner, sentinel, marker)
          ensure
            unless File.file?(sentinel) && Digest::SHA256.file(sentinel).hexdigest == digest && !File.exist?(marker)
              raise Calibration::Rejected, "forbidden reference sentinel changed or invoked"
            end
          end
        end
      end
    end
  end
end
