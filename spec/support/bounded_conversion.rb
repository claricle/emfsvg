# frozen_string_literal: true

require "open3"
require "rbconfig"
require "tempfile"

module Emfsvg
  module SpecSupport
    class BoundedConversion
      class PreconditionError < StandardError; end

      SAMPLE_INTERVAL = 0.01
      LINUX_FIELDS = { rss_kib: "VmRSS", rss_peak_kib: "VmHWM", as_kib: "VmSize", as_peak_kib: "VmPeak" }.freeze

      def self.run(command:, basename:, timeout_seconds:, rss_cap_mib:, as_cap_mib:, grace_seconds:, authoritative:)
        new(basename: basename, timeout_seconds: timeout_seconds, rss_cap_mib: rss_cap_mib,
            as_cap_mib: as_cap_mib, grace_seconds: grace_seconds, authoritative: authoritative).run(command)
      end

      def initialize(basename:, timeout_seconds:, rss_cap_mib:, as_cap_mib:, grace_seconds:, authoritative:)
        @basename = File.basename(basename)
        @limits = { timeout_seconds: timeout_seconds, rss_cap_mib: rss_cap_mib,
                    as_cap_mib: as_cap_mib, grace_seconds: grace_seconds }
        @limits.each do |name, value|
          unless value.is_a?(Numeric) && value.finite? && value.positive?
            fail_precondition("#{name} must be finite and positive")
          end
        end
        @linux = RbConfig::CONFIG.fetch("host_os").include?("linux")
        @darwin = RbConfig::CONFIG.fetch("host_os").include?("darwin")
        fail_precondition("authoritative must be true or false") unless [true, false].include?(authoritative)
        fail_precondition("unsupported operating system") unless @linux || @darwin
        fail_precondition("authoritative address-space enforcement unavailable on macOS") if authoritative && !@linux
        fail_precondition("RLIMIT_AS unavailable") if @linux && !Process.const_defined?(:RLIMIT_AS)
        @metrics = {}
      end

      def run(command)
        fail_precondition("command must be a nonempty argument array") unless command.is_a?(Array) && !command.empty?
        sample(Process.pid) # Verify the real sampler before starting any work.
        Tempfile.create("bounded-stdout") do |output|
          Tempfile.create("bounded-stderr") do |error|
            execute(command, output, error)
          end
        end
      rescue SystemCallError, IOError => e
        fail_precondition("#{e.class}: #{e.message}")
      ensure
        terminate_group if @pid && !@finished
      end

      private

      def execute(command, output, error)
        reader, writer = IO.pipe
        options = { pgroup: true, out: output, err: error, 3 => reader }
        options[:rlimit_as] = [as_bytes, as_bytes] if @linux
        @started = monotonic
        @pid = Process.spawn(RbConfig.ruby, "-e", "IO.for_fd(3).read(1); exec(*ARGV)", *command, options)
        reader.close
        record(sample(@pid))
        writer.write("g")
        writer.close
        breach = watch
        terminate_group if breach
        # A successful leader must not leave descendants running either.
        if group_alive?
          breach ||= :descendants
          terminate_group
        end
        @finished = true
        output.rewind
        error.rewind
        report(breach).merge(stdout: output.read, stderr: error.read)
      ensure
        reader&.close unless reader&.closed?
        writer&.close unless writer&.closed?
      end

      def watch
        loop do
          waited = Process.waitpid2(@pid, Process::WNOHANG)
          if waited
            @status = waited.last
            return nil
          end
          return :timeout if monotonic - @started >= @limits.fetch(:timeout_seconds)

          begin
            record(sample(@pid))
          rescue PreconditionError
            waited = Process.waitpid2(@pid, Process::WNOHANG)
            raise unless waited

            @status = waited.last
            return nil
          end
          return :rss if @metrics.fetch(:rss_kib) > @limits.fetch(:rss_cap_mib) * 1024

          sleep SAMPLE_INTERVAL
        end
      end

      def sample(pid)
        return linux_sample(pid) if @linux

        output, error, status = Open3.capture3("/bin/ps", "-o", "rss=", "-p", pid.to_s)
        fail_precondition("ps RSS unavailable: #{error.strip}") unless status.success? && output.strip.match?(/\A\d+\z/)
        { rss_kib: Integer(output.strip) }
      rescue SystemCallError => e
        fail_precondition("memory sampler unavailable: #{e.message}")
      end

      def linux_sample(pid)
        status = File.read("/proc/#{pid}/status")
        LINUX_FIELDS.to_h do |key, field|
          value = status.match(/^#{field}:\s+(\d+)\s+kB$/)
          fail_precondition("missing or unparsable #{field} for PID #{pid}") unless value
          [key, Integer(value[1])]
        end
      end

      def record(values)
        values.each { |key, value| @metrics[key] = [@metrics.fetch(key, 0), value].max }
      end

      def terminate_group
        signal_group("TERM")
        deadline = monotonic + @limits.fetch(:grace_seconds)
        loop do
          @status ||= Process.waitpid2(@pid, Process::WNOHANG)&.last
          break unless group_alive? && monotonic < deadline

          sleep SAMPLE_INTERVAL
        end
        signal_group("KILL") if group_alive?
        @status ||= Process.waitpid2(@pid).last
      rescue Errno::ECHILD
        nil
      rescue Errno::EPERM => e
        fail_precondition("process-group enforcement unavailable: #{e.message}")
      end

      def signal_group(signal)
        Process.kill(signal, -@pid)
      rescue Errno::ESRCH
        nil
      end

      def group_alive?
        Process.kill(0, -@pid)
        true
      rescue Errno::ESRCH
        false
      end

      def report(breach)
        { basename: @basename, breach: breach, status: @status.signaled? ? :signaled : :exited,
          exitstatus: @status.exitstatus, signal: @status.termsig,
          success: @status.success? == true && breach.nil?, elapsed_seconds: monotonic - @started,
          metrics: @metrics, limits: @limits,
          mechanism: { rss: @linux ? "/proc/status" : "ps RSS", time: "monotonic parent watchdog",
                       address_space: @linux ? "child RLIMIT_AS" : "unsupported" } }
      end

      def as_bytes
        (@limits.fetch(:as_cap_mib) * 1024 * 1024).to_i
      end

      def monotonic
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def fail_precondition(message)
        raise PreconditionError, "#{@basename}: #{message}"
      end
    end
  end
end
