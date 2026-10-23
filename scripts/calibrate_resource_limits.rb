# frozen_string_literal: true

require "optparse"
require_relative "support/resource_calibration"

module Emfsvg
  module ResourceCalibration
    module Command
      module_function

      def run(arguments, output: $stdout, error_output: $stderr, qualification: Prerequisites,
              runner: SpecSupport::BoundedConversion)
        mode, options = parse(arguments.dup)
        Limits.validate!(options.fetch(:caps))
        required = mode == "generate" ? :output : :baseline
        %i[manifest fixture_root].push(required).each do |key|
          raise Rejected, "--#{key.to_s.tr('_', '-')} is required" unless options[key]
        end
        adapter = qualification.verify!(options.fetch(:manifest), options.fetch(:fixture_root))
        Session.new(adapter: adapter, caps: options.fetch(:caps), runner: runner)
               .execute(mode: mode, path: options.fetch(required), output: output)
        0
      rescue Rejected, OptionParser::ParseError, Psych::Exception, SystemCallError,
             SpecSupport::BoundedConversion::PreconditionError => e
        error_output.puts "Resource calibration refused: #{e.message}"
        1
      end

      def parse(arguments)
        mode = arguments.shift
        raise Rejected, "mode must be generate or check" unless %w[generate check].include?(mode)

        options = { caps: {} }
        parser = OptionParser.new do |opts|
          %w[manifest fixture-root output baseline].each do |name|
            opts.on("--#{name} PATH") { |value| options[name.tr("-", "_").to_sym] = value }
          end
          { "timeout-seconds" => "timeout_seconds", "outer-rss-cap-mib" => "rss_cap_mib",
            "outer-as-cap-mib" => "as_cap_mib" }.each do |flag, key|
            opts.on("--#{flag} NUMBER", Float) { |value| options[:caps][key] = value }
          end
        end
        parser.parse!(arguments)
        raise Rejected, "unexpected arguments: #{arguments.join(' ')}" unless arguments.empty?

        [mode, options]
      end
    end
  end
end

exit Emfsvg::ResourceCalibration::Command.run(ARGV) if $PROGRAM_NAME == __FILE__
