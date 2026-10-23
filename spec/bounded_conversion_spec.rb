# frozen_string_literal: true

require "spec_helper"
require "socket"

RSpec.describe Emfsvg::SpecSupport::BoundedConversion do
  include Emfsvg::SpecSupport::BoundedConversionFixture

  it "requires explicit finite positive limits before executing work" do
    Dir.mktmpdir("bounded-precondition-") do |directory|
      marker = File.join(directory, "executed")
      expect { bounded_run("File.write(#{marker.inspect}, 'bad')", timeout_seconds: 0) }
        .to raise_error(described_class::PreconditionError, /benign\.emf: timeout_seconds/)
      expect(File.exist?(marker)).to be(false)
    end
  end

  shared_examples "an enforcement failure diagnosis" do |breach, limits|
    it "preserves the originating #{breach} breach when process-group enforcement is denied" do
      unless %w[linux darwin].any? { |platform| RbConfig::CONFIG.fetch("host_os").include?(platform) }
        skip "process-group enforcement unavailable on this operating system"
      end

      child_pid = nil
      denied = false
      allow(Process).to receive(:kill).and_wrap_original do |original, signal, pid|
        if signal == "TERM"
          denied = true
          raise Errno::EPERM, "controlled group denial"
        end
        original.call(signal, pid)
      end
      sampler = lambda do |pid|
        child_pid = pid unless pid == Process.pid
        { rss_kib: 2048 }
      end

      expect { bounded_run("sleep 30", sampler: sampler, **limits) }
        .to raise_error(described_class::PreconditionError, /process-group enforcement unavailable/) { |error|
          expect(error.report).to include(basename: "benign.emf", breach: breach, success: false,
                                          status: :unknown, exitstatus: nil, signal: nil)
          expect(error.report.fetch(:metrics)).to include(rss_kib: 2048)
          expect(error.report.fetch(:limits)).to include(as_cap_mib: 512, grace_seconds: 0.1, **limits)
          expect(error.report.fetch(:elapsed_seconds)).to be_positive
          expect(error.report.fetch(:mechanism)).to include(time: "monotonic parent watchdog")
        }
      expect(denied).to be(true)
      reap_bounded_child(child_pid)
      expect { Process.kill(0, child_pid) }.to raise_error(Errno::ESRCH)
      expect { Process.waitpid(child_pid, Process::WNOHANG) }.to raise_error(Errno::ECHILD)
    ensure
      reap_bounded_child(child_pid)
    end
  end

  include_examples "an enforcement failure diagnosis", :rss, { rss_cap_mib: 1 }
  include_examples "an enforcement failure diagnosis", :timeout, { timeout_seconds: 0.03 }

  it "rejects missing required limits" do
    expect { described_class.run(command: [RbConfig.ruby], basename: "missing.emf") }
      .to raise_error(ArgumentError, /missing keywords/)
  end

  it "rejects an invalid sampler before executing work" do
    expect { bounded_run("exit", sampler: false) }
      .to raise_error(described_class::PreconditionError, /sampler must be callable/)
    allow(RbConfig::CONFIG).to receive(:fetch).with("host_os").and_return("darwin")
    sampler = ->(_pid) { raise described_class::PreconditionError, "sampler unavailable" }
    expect { bounded_run("exit", sampler: sampler) }
      .to raise_error(described_class::PreconditionError, /sampler unavailable/)
  end

  it "refuses authoritative macOS address-space evidence" do
    skip "macOS capability check" unless RbConfig::CONFIG.fetch("host_os").include?("darwin")

    expect { bounded_run("exit", authoritative: true) }
      .to raise_error(described_class::PreconditionError,
                      /benign\.emf: authoritative address-space enforcement unavailable/)
  end

  it "fails the precondition when the real RSS sampler is unavailable" do
    allow(RbConfig::CONFIG).to receive(:fetch).with("host_os").and_return("darwin")
    allow(Open3).to receive(:capture3).with("/bin/ps", "-o", "rss=", "-p", Process.pid.to_s)
                                      .and_raise(Errno::ENOENT)
    Dir.mktmpdir("bounded-no-sampler-") do |directory|
      marker = File.join(directory, "executed")
      expect { bounded_run("File.write(#{marker.inspect}, 'bad')") }
        .to raise_error(described_class::PreconditionError, /benign\.emf: memory sampler unavailable/)
      expect(File.exist?(marker)).to be(false)
    end
  end

  it "rejects an unsupported host before executing work" do
    allow(RbConfig::CONFIG).to receive(:fetch).with("host_os").and_return("mingw32")
    Dir.mktmpdir("bounded-unsupported-host-") do |directory|
      marker = File.join(directory, "executed")
      expect { bounded_run("File.write(#{marker.inspect}, 'bad')") }
        .to raise_error(described_class::PreconditionError, /benign\.emf: unsupported operating system/)
      expect(File.exist?(marker)).to be(false)
    end
  end

  context "with a working real RSS sampler" do
    before do
      skip "Real RSS sampler unavailable on this host" unless bounded_sampler_available?
    end

    it "returns output, status and distinct RSS/address-space evidence for a benign child" do
      result = bounded_run('puts "converted"')
      expect(result).to include(basename: "benign.emf", success: true, exitstatus: 0, signal: nil, breach: nil,
                                stdout: "converted\n", stderr: "")
      expect(result.fetch(:metrics).fetch(:rss_kib)).to be_positive
      expect(result.fetch(:elapsed_seconds)).to be_positive
      if RbConfig::CONFIG.fetch("host_os").include?("linux")
        expect(result.fetch(:mechanism).fetch(:address_space)).to eq("child RLIMIT_AS")
        expect(result.fetch(:metrics)).to include(:rss_peak_kib, :as_kib, :as_peak_kib)
      else
        expect(result.fetch(:mechanism).fetch(:address_space)).to eq("unsupported")
        expect(result.fetch(:metrics).keys).to eq([:rss_kib])
      end
    end

    it "reports an unsuccessful exit with its basename" do
      expect(bounded_run("exit 7")).to include(basename: "benign.emf", success: false, exitstatus: 7, signal: nil)
    end

    it "reaps a real child exiting between unavailable memory samples" do
      with_exiting_sampler(exit_on_retry: true) do |program, sampler, child|
        result = bounded_run(program, sampler: sampler)
        expect(result).to include(success: true, exitstatus: 0, breach: nil, stdout: "converted\n")
        expect(result.fetch(:metrics).fetch(:rss_kib)).to be_positive
        expect(child.fetch(:samples)).to eq(3)
        expect { Process.waitpid(child.fetch(:pid), Process::WNOHANG) }.to raise_error(Errno::ECHILD)
      end
    end

    it "fails closed when memory samples remain unavailable for a live child" do
      with_exiting_sampler(exit_on_retry: false) do |program, sampler, child|
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        expect { bounded_run(program, sampler: sampler) }
          .to raise_error(described_class::PreconditionError, /missing VmRSS/)
        expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1
        expect(child.fetch(:samples)).to eq(3)
        expect { Process.kill(0, child.fetch(:pid)) }.to raise_error(Errno::ESRCH)
      end
    end

    it "kills and reaps a child that ignores TERM after the bounded grace" do
      result = bounded_run('trap("TERM") {}; sleep 30', timeout_seconds: 1.5, grace_seconds: 0.05)
      expect(result).to include(basename: "benign.emf", success: false, breach: :timeout,
                                signal: Signal.list.fetch("KILL"))
      expect(result.fetch(:elapsed_seconds)).to be < 3
    end

    it "terminates the process group and lets its child reap the descendant" do
      Dir.mktmpdir("bounded-descendant-") do |directory|
        pid_file = File.join(directory, "descendant")
        result = bounded_run(bounded_group_program(pid_file), timeout_seconds: 1.5)
        expect(result).to include(success: false, breach: :timeout)
        expect(File.exist?(pid_file)).to be(true)
        pid = Integer(File.read(pid_file))
        expect { Process.kill(0, pid) }.to raise_error(Errno::ESRCH)
      end
    end

    it "enforces a tiny RSS cap without allocating a large input" do
      result = bounded_run("sleep 30", rss_cap_mib: 1)
      expect(result).to include(success: false, breach: :rss)
      expect(result.fetch(:metrics).fetch(:rss_kib)).to be > 1024
    end

    it "sets only the Linux child's separate address-space ceiling" do
      unless RbConfig::CONFIG.fetch("host_os").include?("linux")
        skip "Linux RLIMIT_AS enforcement unavailable on this platform"
      end

      parent_limits = Process.getrlimit(Process::RLIMIT_AS)
      result = bounded_run('puts Process.getrlimit(Process::RLIMIT_AS).join(",")', authoritative: true)
      expect(result).to include(success: true, stdout: "536870912,536870912\n")
      expect(Process.getrlimit(Process::RLIMIT_AS)).to eq(parent_limits)
    end
  end
end
