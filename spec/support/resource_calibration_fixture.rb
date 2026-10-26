# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    module ResourceCalibrationFixture
      Runner = Struct.new(:report) do
        def run(**_options)
          report
        end
      end
      Adapter = Struct.new(:snapshot, :inputs, :child_command, :conversion) do
        def command(_input)
          child_command
        end

        def validate_report!(_input, _report)
          conversion
        end
      end
      Qualification = Struct.new(:adapter) do
        def verify!(*_arguments, **_options)
          adapter
        end
      end

      def calibration_git(directory, *arguments)
        output, status = Open3.capture2e("git", "-C", directory, *arguments)
        raise output unless status.success?

        output.strip
      end

      def calibration_source_repository(directory)
        FileUtils.mkdir_p(File.join(directory, "lib"))
        FileUtils.mkdir_p(File.join(directory, "spec/fixtures"))
        File.write(File.join(directory, "lib/implementation.rb"), "original implementation")
        File.write(File.join(directory, "Gemfile.lock"), "pinned dependencies")
        calibration_git(directory, "init", "-q")
        calibration_git(directory, "config", "user.email", "fixture@example.test")
        calibration_git(directory, "config", "user.name", "Fixture")
        calibration_git(directory, "add", ".")
        calibration_git(directory, "commit", "-qm", "Initial implementation")
      end

      def calibration_caps
        { "timeout_seconds" => 100, "rss_cap_mib" => 1024, "as_cap_mib" => 2048 }
      end

      def calibration_provenance
        { "manifest_sha256" => "a" * 64, "emfsvg_revision" => "b" * 40, "emfsvg_source_sha256" => "2" * 64,
          "runtime" => { "version" => "1.2.3", "package_sha256" => "c" * 64, "source_revision" => "d" * 40 },
          "native_library" => { "artifact_sha256" => "e" * 64, "source_revision" => "f" * 40, "abi" => "synthetic" },
          "selected_backend" => "native", "platform" => { "os" => "linux", "architecture" => "synthetic",
                                                          "ruby" => RUBY_VERSION },
          "enforcement" => { "rss" => "/proc/status", "address_space" => "child RLIMIT_AS",
                             "time" => "monotonic parent watchdog" } }
      end

      def calibration_input(name = "synthetic.emf")
        { "name" => name, "sha256" => "1" * 64, "expected_outcome" => { "type" => "svg" } }
      end

      def calibration_report
        { success: true, breach: nil, status: :exited, exitstatus: 0, signal: nil, stdout: "synthetic public report",
          elapsed_seconds: 0.51, metrics: { rss_peak_kib: 1025, as_peak_kib: 4097 },
          mechanism: calibration_provenance.fetch("enforcement") }
      end

      def calibration_adapter(inputs = [calibration_input])
        Adapter.new(calibration_provenance, inputs, ["synthetic-child"],
                    { "input_bytes" => 100, "output_bytes" => 150, "warnings" => [], "exception" => nil })
      end

      def calibration_document
        runner = Runner.new(calibration_report)
        Emfsvg::ResourceCalibration::Session.new(adapter: calibration_adapter, caps: calibration_caps,
                                                 runner: runner).collect
      end

      def calibration_arguments(mode, path)
        [mode, "--manifest", ParityProvenance::DEFAULT_MANIFEST, "--fixture-root", "/unread-corpus",
         "--outer-rss-cap-mib", "1024", "--outer-as-cap-mib", "2048", "--timeout-seconds", "100",
         mode == "generate" ? "--output" : "--baseline", path]
      end
    end
  end
end
