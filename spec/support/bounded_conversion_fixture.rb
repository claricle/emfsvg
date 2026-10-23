# frozen_string_literal: true

require "tmpdir"

module Emfsvg
  module SpecSupport
    module BoundedConversionFixture
      def wait_for_zombie(pid)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1
        loop do
          state, = Open3.capture3("/bin/ps", "-o", "stat=", "-p", pid.to_s)
          return if state.strip.start_with?("Z")
          raise "child did not exit" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        end
      end

      def with_exiting_sampler(exit_on_retry:)
        Dir.mktmpdir("bounded-sampler-") do |directory|
          path = File.join(directory, "child.sock")
          server = UNIXServer.new(path)
          child = { samples: 0 }
          connection = nil
          sampler = lambda do |pid|
            if pid != Process.pid
              child[:pid] = pid
              child[:samples] += 1
              if child[:samples] > 1
                connection ||= server.accept.tap(&:gets)
                if exit_on_retry && child[:samples] == 3
                  connection.puts("exit")
                  wait_for_zombie(pid)
                end
                raise BoundedConversion::PreconditionError, "missing VmRSS for PID #{pid}"
              end
            end
            rss, = Open3.capture3("/bin/ps", "-o", "rss=", "-p", pid.to_s)
            { rss_kib: Integer(rss.strip) }
          end
          program = <<~RUBY
            require "socket"
            socket = UNIXSocket.new(#{path.inspect})
            socket.puts("ready")
            socket.gets
            puts "converted"
          RUBY
          yield program, sampler, child
        ensure
          connection&.close
          server&.close
        end
      end

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
