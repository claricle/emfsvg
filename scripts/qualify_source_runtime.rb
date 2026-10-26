# frozen_string_literal: true

require_relative "support/source_qualification"

module Emfsvg
  module ResourceCalibration
    module SourceCommand
      module_function

      def run(arguments, output: $stdout, error_output: $stderr)
        raise Rejected, "usage: qualify_source_runtime.rb MANIFEST FIXTURE_ROOT OUTPUT_JSON" unless arguments.size == 3

        manifest, root, destination = arguments
        adapter = SourceQualification.new(manifest: manifest, fixture_root: root).verify!
        samples = 3.times.flat_map do |repetition|
          adapter.inputs.map do |input|
            report = SpecSupport::BoundedConversion.run(command: adapter.command(input), basename: input.fetch("name"),
                                                        **Qualification::CAPS.merge(authoritative: true))
            unless report[:success] == true && report[:breach].nil? && report[:signal].nil? &&
                   report[:status] == :exited && report[:exitstatus].eql?(0)
              raise Rejected, "unsafe source calibration child: #{input.fetch('name')}"
            end

            mechanism = report.fetch(:mechanism).transform_keys(&:to_s).transform_values(&:to_s)
            unless mechanism == adapter.snapshot.fetch("enforcement")
              raise Rejected,
                    "source calibration enforcement drift"
            end

            adapter.validate_report!(input, report)
            report.except(:stdout, :stderr)
                  .merge(repetition: repetition + 1, input: input)
          end
        end
        result = { "schema_version" => 1, "scope" => "prerelease-source",
                   "released_runtime_qualified" => false, "provenance" => adapter.snapshot,
                   "conformance" => { "ruby" => 30, "native" => 30, "auto" => 30 }, "samples" => samples }
        File.write(destination, "#{JSON.pretty_generate(result)}\n")
        output.puts "Prerelease source qualification passed: 90 conformance cases, 90 bounded auto samples."
        0
      rescue Rejected, SystemCallError, Psych::Exception, SpecSupport::BoundedConversion::PreconditionError => e
        error_output.puts "Prerelease source qualification refused: #{e.message}"
        1
      end
    end
  end
end

exit Emfsvg::ResourceCalibration::SourceCommand.run(ARGV) if $PROGRAM_NAME == __FILE__
