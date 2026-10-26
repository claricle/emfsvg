# frozen_string_literal: true

require "rbconfig"
require "shellwords"

module Emfsvg
  module SpecSupport
    module CompatReferenceFixture
      def windows_reference?
        RbConfig::CONFIG.fetch("host_os").match?(/mswin|mingw|cygwin/i)
      end

      def compat_reference_wrapper(mode)
        return "@echo off\n\"#{RbConfig.ruby}\" \"#{__FILE__}\" #{mode} \"%~1\" \"%~2\"\n" if windows_reference?

        "#!/bin/sh\nexec #{Shellwords.escape(RbConfig.ruby)} #{Shellwords.escape(__FILE__)} #{mode} \"$1\" \"$2\"\n"
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  mode, input_path, output_path = ARGV
  File.write(input_path, output_path)
  case mode
  when "success"
    File.binwrite(output_path, "<svg/>")
  when "failure"
    File.binwrite(output_path, "partial")
    warn "invalid EMF"
    exit 7
  when "empty"
    File.binwrite(output_path, "")
  when "missing"
    # A successful process without an output must still fail the reference gate.
  else
    abort "unknown reference fixture mode: #{mode.inspect}"
  end
end
