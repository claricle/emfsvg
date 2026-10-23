# frozen_string_literal: true

require "digest"
require "json"
require "rexml/document"
require "yaml"

module Emfsvg
  # A reviewed ledger is an explicit trust boundary, not authenticated evidence or
  # runtime qualification. Manifest outcomes and conversion snapshots are not oracles.
  class CorruptOutcomeContract
    class Rejected < StandardError; end

    def initialize(manifest:, ledger: {})
      manifest = YAML.safe_load_file(manifest) if manifest.is_a?(String)
      @inputs = manifest.fetch("corrupted")
      @ledger = ledger
      raise Rejected, "invalid corrupted inventory" unless @inputs.is_a?(Array) && !@inputs.empty? && @inputs.all?(Hash)
      raise Rejected, "ledger must be keyed by input name" unless ledger.is_a?(Hash)

      names = @inputs.map { |input| input.fetch("name") }
      raise Rejected, "duplicate input names" unless names.uniq.size == names.size
      raise Rejected, "unknown ledger inputs" unless (ledger.keys - names).empty?

      @inputs.each do |input|
        source = input.fetch("source")
        unless input["name"].is_a?(String) && source.is_a?(Hash) && source["path"].is_a?(String) &&
               !source["path"].empty? && digest?(source["sha256"])
          raise Rejected, "invalid manifest input identity"
        end
      end
    rescue KeyError, TypeError, NoMethodError => e
      raise Rejected, "invalid manifest: #{e.message}"
    end

    def report(observations: {})
      raise Rejected, "observations must be keyed by input name" unless observations.is_a?(Hash)

      names = @inputs.map { |input| input.fetch("name") }
      raise Rejected, "unknown observation inputs" unless (observations.keys - names).empty?

      cases = @inputs.sort_by { |input| input.fetch("name") }.map do |input|
        case_report(input, observations)
      end
      counts = %w[contracted matched unresolved mismatch].to_h do |status|
        [status, cases.count { |entry| entry["status"] == status }]
      end
      status = if counts["mismatch"].positive?
                 "mismatch"
               elsif counts["unresolved"].positive?
                 "unresolved"
               else
                 "contracted"
               end
      { "schema_version" => 1, "status" => status, "counts" => counts, "cases" => cases }
    end

    def validate_observation!(name, observation)
      input = @inputs.find { |entry| entry["name"] == name }
      raise Rejected, "unknown input #{name}" unless input

      record = @ledger[name]
      missing = requirements(record)
      raise Rejected, "unresolved: #{missing.join(', ')}" unless missing.empty?
      raise Rejected, "ledger source mismatch" unless record["source"] == input["source"]
      raise Rejected, "observation source mismatch" unless observation.fetch("source") == input["source"]

      expected = record.fetch("expected_outcome")
      raise Rejected, "warning mismatch" unless observation.fetch("warnings") == expected.fetch("warnings")

      if expected.fetch("kind") == "svg"
        svg = observation.fetch("svg")
        valid = svg.is_a?(String) && observation.fetch("exception").nil? &&
                observation.fetch("output_bytes") == svg.bytesize
        valid &&= svg_digest_matches?(svg, expected)
        raise Rejected, "SVG digest/bytes or exception mismatch" unless valid

        validate_svg!(svg)
      else
        valid = observation.fetch("svg").nil? && observation.fetch("output_bytes").eql?(0) &&
                observation.fetch("exception") == expected.fetch("exception")
        raise Rejected, "exception/cause mismatch or partial SVG" unless valid
      end
      true
    rescue KeyError, TypeError, NoMethodError => e
      raise Rejected, "invalid observation: #{e.message}"
    end

    private

    def validate_svg!(svg)
      root = REXML::Document.new(svg).root
      return if root && root.name == "svg" && root.namespace == "http://www.w3.org/2000/svg"

      raise Rejected, "invalid SVG root"
    rescue REXML::ParseException => e
      raise Rejected, "invalid SVG: #{e.message}"
    end

    def svg_digest_matches?(svg, expected)
      !expected.key?("svg_sha256") || Digest::SHA256.hexdigest(svg) == expected.fetch("svg_sha256")
    end

    def case_report(input, observations)
      name = input.fetch("name")
      record = @ledger[name]
      result = input.slice("name", "source").merge("status" => "unresolved", "requirements" => requirements(record))
      if record.is_a?(Hash) && record["source"] != input["source"]
        return result.merge("status" => "mismatch", "error" => "ledger source mismatch")
      end
      return result unless result["requirements"].empty?

      result = result.merge("status" => "contracted", "expected_outcome" => record.fetch("expected_outcome"),
                            "evidence" => record.fetch("evidence"))
      return result unless observations.key?(name)

      validate_observation!(name, observations.fetch(name))
      result.merge("status" => "matched")
    rescue Rejected => e
      result.merge("status" => "mismatch", "error" => e.message)
    end

    def requirements(record)
      record = {} unless record.is_a?(Hash)
      missing = []
      missing << "reviewed (explicit true attestation)" unless record["reviewed"] == true
      missing << "independent requirement/reference evidence" unless evidence?(record["evidence"])
      expected = record["expected_outcome"]
      unless expected.is_a?(Hash)
        return missing + ["expected_outcome.kind", "expected_outcome.warnings (exact ordered values)",
                          "expected_outcome digest (optional for svg) or failure details"]
      end

      missing + outcome_requirements(expected)
    end

    def evidence?(evidence)
      kinds = %w[requirement reference]
      evidence.is_a?(Array) && !evidence.empty? && evidence.all? do |entry|
        exact_keys?(entry, %w[kind reference]) && kinds.include?(entry["kind"]) &&
          entry["reference"].is_a?(String) && !entry["reference"].strip.empty?
      end
    end

    def outcome_requirements(expected)
      missing = []
      warnings = expected["warnings"]
      unless warnings.is_a?(Array) && warnings.all?(String)
        missing << "expected_outcome.warnings (exact ordered strings)"
      end
      kind = expected["kind"]
      case kind
      when "svg"
        fields = %w[kind warnings]
        if expected.key?("svg_sha256")
          missing << "expected_outcome.svg_sha256 (64 lowercase hex characters)" unless digest?(expected["svg_sha256"])
          fields << "svg_sha256"
        end
      when "unreadable", "resource"
        missing.concat(exception_requirements(expected["exception"], kind))
        fields = %w[exception kind warnings]
      else
        missing << "expected_outcome.kind (svg, unreadable or resource)"
        missing << "expected_outcome digest (optional for svg) or failure details"
        return missing
      end
      missing << "expected_outcome exact fields: #{fields.sort.join(', ')}" unless exact_keys?(expected, fields.sort)
      missing
    end

    def exception_requirements(exception, kind)
      klass = kind == "unreadable" ? "Emfsvg::ParseError" : "Emfsvg::ResourceLimitError"
      fields = kind == "unreadable" ? %w[cause class message] : %w[actual cause class limit message resource]
      missing = []
      unless exact_keys?(exception, fields) && exception["class"] == klass && exception["message"].is_a?(String)
        missing << "expected_outcome.exception (#{klass}; exact #{fields.join(', ')})"
        return missing
      end
      cause = exception["cause"]
      unless (kind == "resource" && cause.nil?) || message_cause?(cause) || resource_cause?(cause)
        missing << "expected_outcome.exception.cause (original class/message)"
      end
      if kind == "resource" && (!resource_metadata?(exception) || !matching_resource_cause?(exception, cause))
        missing << "expected_outcome.exception resource/limit/actual and matching upstream cause"
      end
      missing
    end

    def matching_resource_cause?(exception, cause)
      return true if cause.nil?

      resource_cause?(cause) && %w[resource limit actual].all? { |field| exception[field] == cause[field] }
    end

    def message_cause?(cause)
      exact_keys?(cause, %w[class message]) && cause["class"].is_a?(String) &&
        !cause["class"].empty? && cause["message"].is_a?(String)
    end

    def resource_cause?(cause)
      exact_keys?(cause, %w[actual class limit message resource]) && cause["class"] == "Emf::ResourceLimitError" &&
        cause["message"].is_a?(String) && resource_metadata?(cause)
    end

    def resource_metadata?(exception)
      exception["resource"].is_a?(String) && !exception["resource"].empty? && exception["limit"].is_a?(Integer) &&
        exception["limit"] >= 0 && exception["actual"].is_a?(Integer) && exception["actual"] > exception["limit"]
    end

    def digest?(value)
      value.is_a?(String) && value.match?(/\A[0-9a-f]{64}\z/)
    end

    def exact_keys?(value, fields)
      value.is_a?(Hash) && value.keys.all?(String) && value.keys.sort == fields
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    unless (1..3).cover?(ARGV.length)
      raise Emfsvg::CorruptOutcomeContract::Rejected,
            "usage: ruby #{File.basename(__FILE__)} MANIFEST [LEDGER.json] [OBSERVATIONS.json]"
    end

    manifest, ledger, observations = ARGV
    contract = Emfsvg::CorruptOutcomeContract.new(manifest: manifest,
                                                  ledger: ledger ? JSON.parse(File.read(ledger)) : {})
    report = contract.report(observations: observations ? JSON.parse(File.read(observations)) : {})
    puts JSON.pretty_generate(report)
    exit(report["counts"].values_at("unresolved", "mismatch").sum.zero? ? 0 : 1)
  rescue Emfsvg::CorruptOutcomeContract::Rejected, Psych::Exception, JSON::ParserError, SystemCallError => e
    puts JSON.generate("status" => "rejected", "error" => e.message)
    exit 1
  end
end
