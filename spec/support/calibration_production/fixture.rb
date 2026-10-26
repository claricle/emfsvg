# frozen_string_literal: true

require "digest"
require "open3"
require "tmpdir"

module Emfsvg
  module SpecSupport
    module CalibrationProductionFixture
      def production_input(directory, name, bytes, outcome)
        File.binwrite(File.join(directory, name), bytes)
        { "name" => name, "sha256" => Digest::SHA256.hexdigest(bytes), "expected_outcome" => outcome }
      end

      def production_adapter(directory, inputs, library: ENV.fetch("EMF_NATIVE_LIBRARY"))
        Emfsvg::ResourceCalibration::ProductionAdapter.new(
          fixture_root: directory, inputs: inputs, provenance: -> { production_provenance(library) },
          runtime_entrypoint: $LOADED_FEATURES.find { |path| path.end_with?("/emf.rb") }, native_library: library
        )
      end

      def production_provenance(library)
        { "runtime" => { "version" => Emf::VERSION },
          "native_library" => { "artifact_sha256" => Digest::SHA256.file(library).hexdigest } }
      end

      def production_report(adapter, input, preload: nil)
        command = adapter.command(input)
        command.insert(1, "-r", preload) if preload
        capture_production_report(command)
      end

      def capture_production_report(command)
        output, error, status = Open3.capture3(*command)
        raise "conversion child failed: #{error}" unless status.success?

        { stdout: output, stderr: error }
      end

      def production_svg_outcome(bytes, warnings: [])
        { "kind" => "svg", "warnings" => warnings, "svg_sha256" => Digest::SHA256.hexdigest(Emfsvg.from_bytes(bytes)) }
      end

      def production_exception(error)
        result = { "class" => error.class.name, "message" => error.message }
        if error.is_a?(Emfsvg::ResourceLimitError) || error.is_a?(Emf::ResourceLimitError)
          result.merge!("resource" => error.resource.to_s, "limit" => error.limit, "actual" => error.actual)
        end
        result
      end

      def production_failure_outcome(bytes, kind)
        Emfsvg.from_bytes(bytes)
        raise "expected conversion failure"
      rescue Emfsvg::ParseError, Emfsvg::ResourceLimitError => e
        { "kind" => kind, "warnings" => [],
          "exception" => production_exception(e).merge("cause" => e.cause && production_exception(e.cause)) }
      end
    end
  end
end
