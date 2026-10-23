# frozen_string_literal: true

require "tmpdir"

module Emfsvg
  module SpecSupport
    module BoundedConversionFixture
      def bounded_run(program, **overrides)
        BoundedConversion.run(command: [RbConfig.ruby, "-e", program], basename: "/fixtures/benign.emf",
                              timeout_seconds: 3, rss_cap_mib: 128, as_cap_mib: 512, grace_seconds: 0.1,
                              authoritative: false, **overrides)
      end

      def reap_bounded_child(pid)
        return unless pid
        return if Process.waitpid(pid, Process::WNOHANG)

        Process.kill("KILL", pid)
        Process.waitpid(pid)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      end

      def bounded_sampler_available?
        return true if RbConfig::CONFIG.fetch("host_os").include?("linux")

        _, _, status = Open3.capture3("/bin/ps", "-o", "rss=", "-p", Process.pid.to_s)
        status.success?
      rescue SystemCallError
        false
      end

      def bounded_group_program(path)
        <<~RUBY
          child = fork do
            trap("TERM") { exit! }
            File.write(#{path.inspect}, Process.pid.to_s)
            sleep 30
          end
          trap("TERM") { Process.wait(child); exit! }
          sleep 30
        RUBY
      end
    end
  end
end
