# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"
require "tmpdir"

module Emfsvg
  module SpecSupport
    module RuntimeIsolationFixture
      def runtime_isolation_observation(mode)
        Dir.mktmpdir("emfsvg-runtime-isolation-") do |directory|
          marker = File.join(directory, "forbidden-reference-called")
          sentinel = File.join(directory, "forbidden-reference")
          File.write(sentinel, "#!/bin/sh\nprintf 'called' > \"#{marker}\"\nexit 97\n")
          File.chmod(0o755, sentinel)
          environment = { "EMF2SVG_REF_PATH" => sentinel, "EMF2SVG_REF_LIB_DIR" => sentinel }
          output, error, status = Open3.capture3(environment, RbConfig.ruby,
                                                 "-I", File.expand_path("../../lib", __dir__),
                                                 "-e", runtime_isolation_program, mode)
          raise "Isolation subprocess failed (#{status}): #{error}" unless status.success?

          JSON.parse(output).merge("sentinel_called" => File.exist?(marker))
        end
      end

      def runtime_isolation_program
        <<~'RUBY'
          require "json"
          require "open3"
          require "rbconfig"
          require "emfsvg"

          result = begin
            bytes = if ARGV.fetch(0) == "supported"
                      Emfsvg.from_svg('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">' \
                                      '<rect x="1" y="1" width="2" height="2"/></svg>')
                    else
                      "unreadable EMF bytes"
                    end
            value = Emfsvg.from_bytes(bytes)
            { "value_class" => value.class.name, "svg" => value }
          rescue StandardError => e
            { "error_class" => e.class.name, "error_message" => e.message }
          end

          if File.readable?("/proc/self/maps")
            mappings = File.read("/proc/self/maps")
            inspection = { "status" => "available", "method" => "/proc/self/maps" }
          elsif RbConfig::CONFIG.fetch("host_os").include?("darwin") && File.executable?("/usr/bin/vmmap")
            mappings, error, status = Open3.capture3("/usr/bin/vmmap", "-w", Process.pid.to_s)
            inspection = if status.success?
                           { "status" => "available", "method" => "vmmap" }
                         else
                           { "status" => "unsupported", "reason" => "vmmap: #{error.lines.first.to_s.strip}" }
                         end
          else
            inspection = { "status" => "unsupported", "reason" => "No readable /proc/self/maps or executable vmmap" }
          end
          inspection["forbidden_libraries"] = mappings.lines.grep(/libemf2svg/i) if inspection["status"] == "available"
          result["library_inspection"] = inspection
          result["forbidden_features"] = $LOADED_FEATURES.grep(/libemf2svg|spec[\/]support[\/]emfsvg_compat/i)
          puts JSON.generate(result)
        RUBY
      end
    end
  end
end
