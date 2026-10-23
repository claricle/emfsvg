# frozen_string_literal: true

require "digest"
require "json"
require "rbconfig"
require "rexml/document"
require_relative "resource_calibration"

module Emfsvg
  module ResourceCalibration
    # Session adapter core only. Construction does NOT qualify prerequisites.
    # A future qualified gate must supply the complete provenance reader and
    # manifest-selected inputs; this class never selects or invents that corpus.
    class ProductionAdapter
      def initialize(fixture_root:, inputs:, provenance:, runtime_entrypoint:, native_library:, backend: "auto")
        @root = File.realpath(fixture_root)
        @inputs = JSON.parse(JSON.generate(inputs))
        @provenance = provenance
        @entrypoint = File.realpath(runtime_entrypoint)
        @entrypoint_sha256 = Digest::SHA256.file(@entrypoint).hexdigest
        @native = File.realpath(native_library)
        @backend = backend
        raise Rejected, "production calibration requires auto" unless backend == "auto"
        raise Rejected, "no pinned inputs" if @inputs.empty?

        @inputs.each do |input|
          Baseline.validate_input!(input)
          validate_expected_outcome!(input.fetch("expected_outcome"))
        end
        names = @inputs.map { |input| input.fetch("name") }
        raise Rejected, "duplicate input names" unless names.uniq.size == @inputs.size
      end

      def snapshot
        unless Digest::SHA256.file(@entrypoint).hexdigest == @entrypoint_sha256
          raise Rejected,
                "runtime entrypoint drift"
        end

        value = JSON.parse(JSON.generate(@provenance.call))
        unless value.dig("native_library", "artifact_sha256") == Digest::SHA256.file(@native).hexdigest
          raise Rejected, "native artifact drift"
        end

        value
      end

      def inputs
        @inputs.each { |input| verify_input!(input) }
        JSON.parse(JSON.generate(@inputs))
      end

      def command(input)
        verify_input!(input)
        bootstrap = 'ENV["EMF_BACKEND"], ENV["EMF_NATIVE_LIBRARY"] = ARGV.shift(2); ' \
                    "script = ARGV.shift; $0 = script; load script"
        [RbConfig.ruby, "-I", File.dirname(@entrypoint), "-I", File.expand_path("../../lib", __dir__),
         "-r", "json", "-e", bootstrap,
         @backend, @native, File.expand_path("calibration_conversion_child.rb", __dir__),
         JSON.generate("path" => input_path(input), "sha256" => input.fetch("sha256"))]
      end

      def validate_report!(input, report)
        verify_input!(input)
        raise Rejected, "unexpected child stderr" unless report.fetch(:stderr).empty?

        value = JSON.parse(report.fetch(:stdout))
        validate_identity!(input, value)
        validate_outcome!(input.fetch("expected_outcome"), value)
        value.slice("input_bytes", "output_bytes", "warnings", "exception")
      rescue JSON::ParserError, KeyError, TypeError, NoMethodError => e
        raise Rejected, "invalid conversion report: #{e.message}"
      end

      private

      def validate_expected_outcome!(expected)
        unless expected["warnings"].is_a?(Array) && expected["warnings"].all?(String)
          raise Rejected, "invalid expected warnings"
        end

        case expected["kind"]
        when "svg"
          reject_unexpected_expected_fields!(expected, %w[kind svg_sha256 warnings])
          digest = expected["svg_sha256"]
          raise Rejected, "invalid expected SVG digest" unless digest.is_a?(String) && digest.match?(/\A[0-9a-f]{64}\z/)
        when "unreadable"
          reject_unexpected_expected_fields!(expected, %w[exception kind warnings])
          validate_expected_exception!(expected, "Emfsvg::ParseError")
        when "resource"
          reject_unexpected_expected_fields!(expected, %w[exception kind warnings])
          validate_expected_exception!(expected, "Emfsvg::ResourceLimitError")
          validate_resource!(expected.fetch("exception"))
        else
          raise Rejected, "unknown expected outcome"
        end
      end

      def validate_expected_exception!(expected, klass)
        failure = expected["exception"]
        fields = expected_exception_fields(klass)
        unless exact_string_keys?(failure, fields) && failure["class"] == klass &&
               failure["message"].is_a?(String)
          raise Rejected, "invalid expected exception"
        end

        validate_expected_exception_cause!(failure["cause"])
      end

      def expected_exception_fields(klass)
        return %w[actual cause class limit message resource] if klass == "Emfsvg::ResourceLimitError"

        %w[cause class message]
      end

      def validate_expected_exception_cause!(cause)
        return if cause.nil? || valid_message_cause?(cause) || valid_resource_cause?(cause)

        raise Rejected, "invalid expected exception cause"
      end

      def valid_message_cause?(cause)
        exact_string_keys?(cause, %w[class message]) &&
          cause["class"].is_a?(String) && cause["message"].is_a?(String)
      end

      def valid_resource_cause?(cause)
        fields = %w[actual class limit message resource]
        exact_string_keys?(cause, fields) && cause["class"] == "Emf::ResourceLimitError" &&
          cause["message"].is_a?(String) && cause["resource"].is_a?(String) &&
          cause["limit"].is_a?(Integer) && cause["actual"].is_a?(Integer) && cause["actual"] > cause["limit"]
      end

      def exact_string_keys?(value, fields)
        value.is_a?(Hash) && value.keys.all?(String) && value.keys.sort == fields
      end

      def reject_unexpected_expected_fields!(expected, fields)
        return if exact_string_keys?(expected, fields)

        raise Rejected, "invalid expected outcome fields"
      end

      def input_path(input)
        path = File.realpath(File.join(@root, input.fetch("name")))
        raise Rejected, "input outside fixture root" unless path.start_with?("#{@root}#{File::SEPARATOR}")

        path
      end

      def verify_input!(input)
        raise Rejected, "unselected input" unless @inputs.include?(input)
        return if Digest::SHA256.file(input_path(input)).hexdigest == input.fetch("sha256")

        raise Rejected, "input digest drift"
      end

      def validate_identity!(input, value)
        provenance = snapshot
        expected_runtime = { "entrypoint" => @entrypoint, "sha256" => @entrypoint_sha256,
                             "version" => provenance.fetch("runtime").fetch("version") }
        valid = value.fetch("schema_version") == 1 && value.fetch("input_sha256") == input.fetch("sha256") &&
                value.fetch("input_bytes") == File.size(input_path(input)) &&
                value.fetch("runtime") == expected_runtime &&
                value.fetch("backend") == @backend && value.fetch("native_sha256") == provenance.dig("native_library",
                                                                                                     "artifact_sha256")
        raise Rejected, "child input/runtime/artifact drift" unless valid

        expected = { "selected" => "Emf::Native::Adapter", "method" => "Emf::Backend.send(:selected)",
                     "public_contract" => false }
        return if value.fetch("selection_before") == expected && value.fetch("selection_after") == expected

        raise Rejected, "native-selected auto observation failed (private selector; not qualification)"
      end

      def validate_outcome!(expected, value)
        raise Rejected, "warning mismatch" unless value.fetch("warnings") == expected.fetch("warnings")

        case expected.fetch("kind")
        when "svg" then validate_svg!(expected, value)
        when "unreadable", "resource" then validate_exception!(expected, value)
        else raise Rejected, "unknown expected outcome"
        end
      end

      def validate_svg!(expected, value)
        svg = value.fetch("svg")
        unless svg.is_a?(String) && value.fetch("exception").nil? && value.fetch("output_bytes") == svg.bytesize &&
               Digest::SHA256.hexdigest(svg) == expected.fetch("svg_sha256")
          raise Rejected, "SVG byte mismatch or unexpected exception"
        end

        root = REXML::Document.new(svg).root
        return if root && root.name == "svg" && root.namespace == "http://www.w3.org/2000/svg"

        raise Rejected, "invalid SVG root"
      rescue REXML::ParseException => e
        raise Rejected, "invalid SVG: #{e.message}"
      end

      def validate_exception!(expected, value)
        failure = value.fetch("exception")
        klass = expected.fetch("kind") == "resource" ? "Emfsvg::ResourceLimitError" : "Emfsvg::ParseError"
        unless value.fetch("svg").nil? && value.fetch("output_bytes").zero? &&
               failure.is_a?(Hash) && failure["class"] == klass && failure == expected.fetch("exception")
          raise Rejected, "exception mismatch or partial SVG"
        end
        return unless expected.fetch("kind") == "resource"

        validate_resource!(failure)
      end

      def validate_resource!(failure)
        fields = %w[resource limit actual]
        valid = failure["resource"].is_a?(String) && !failure["resource"].empty? &&
                failure["limit"].is_a?(Integer) && failure["limit"] >= 0 &&
                failure["actual"].is_a?(Integer) && failure["actual"] > failure["limit"]
        raise Rejected, "invalid resource metadata" unless valid

        # Downstream admission/renderer limits have no upstream cause. Exact
        # expected outcome equality above preserves that distinction.
        cause = failure.fetch("cause")
        return if cause.nil?
        return if cause.is_a?(Hash) && cause["class"] == "Emf::ResourceLimitError" &&
                  fields.all? { |key| failure.key?(key) && failure[key] == cause[key] }

        raise Rejected, "resource metadata/cause mismatch"
      end
    end
  end
end
