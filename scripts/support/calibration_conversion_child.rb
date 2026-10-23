# frozen_string_literal: true

require "digest"
require "json"
require "stringio"

module Emfsvg
  module ResourceCalibration
    # Public backend observation; release qualification remains a separate gate.
    class ConversionChild
      def self.exception(error)
        return nil unless error

        result = { "class" => error.class.name, "message" => error.message }
        if error.respond_to?(:resource) && error.respond_to?(:limit) && error.respond_to?(:actual)
          result.merge!("resource" => error.resource.to_s, "limit" => error.limit, "actual" => error.actual)
        end
        result
      end

      def self.selection
        { "selected" => Emf.backend.to_s, "method" => "Emf.backend", "public_contract" => true }
      end

      def self.call(request)
        require "emfsvg"
        path = $LOADED_FEATURES.find { |feature| feature.end_with?("/emf.rb") }
        runtime = { "entrypoint" => File.realpath(path), "sha256" => Digest::SHA256.file(path).hexdigest,
                    "version" => Emf::VERSION }
        before = selection
        bytes = File.binread(request.fetch("path"))
        digest = Digest::SHA256.hexdigest(bytes)
        raise "input digest drift" unless digest == request.fetch("sha256")

        result = convert(bytes)
        result.merge("schema_version" => 1, "input_sha256" => digest, "input_bytes" => bytes.bytesize,
                     "runtime" => runtime, "backend" => ENV.fetch("EMF_BACKEND"),
                     "native_sha256" => Digest::SHA256.file(ENV.fetch("EMF_NATIVE_LIBRARY")).hexdigest,
                     "selection_before" => before, "selection_after" => selection)
      end

      def self.convert(bytes)
        captured = StringIO.new
        previous = $stderr
        $stderr = captured
        svg = nil
        failure = nil
        begin
          svg = Emfsvg.from_bytes(bytes)
        rescue StandardError => e
          failure = exception(e).merge("cause" => exception(e.cause))
        end
        { "svg" => svg, "output_bytes" => svg ? svg.bytesize : 0,
          "warnings" => captured.string.lines, "exception" => failure }
      ensure
        $stderr = previous
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  puts JSON.generate(Emfsvg::ResourceCalibration::ConversionChild.call(JSON.parse(ARGV.fetch(0))))
end
