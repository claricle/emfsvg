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
            mode = ARGV.fetch(0)
            bytes = case mode
                    when "supported"
                      Emfsvg.from_svg('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">' \
                                      '<rect x="1" y="1" width="2" height="2"/></svg>')
                    when "unreadable"
                      "unreadable EMF bytes"
                    else
                      # A valid 24-byte standard WMF with an EOF record. Lower
                      # only the upstream WMF parser's real input guard below.
                      [1, 9, 0x0300, 12, 0, 3, 0].pack("v3VvVv") + [3, 0].pack("Vv")
                    end
            if mode == "resource_limited"
              limit_owner = Emf::Wmf::Binary
              limit_owner.send(:remove_const, :MAX_INPUT_BYTES)
              limit_owner.const_set(:MAX_INPUT_BYTES, bytes.bytesize - 1)
            end
            value = Emfsvg.from_bytes(bytes)
            { "value_class" => value.class.name, "svg" => value }
          rescue StandardError => e
            result = { "error_class" => e.class.name, "error_message" => e.message }
            if e.is_a?(Emfsvg::ResourceLimitError)
              result["metadata"] = [e.resource.to_s, e.limit, e.actual]
              result["cause_class"] = e.cause&.class&.name
              cause = e.cause
              result["cause_metadata"] = [cause.resource.to_s, cause.limit, cause.actual] if cause.respond_to?(:resource)
            end
            result
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
