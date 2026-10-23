# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    module ResourceCalibrationFixture
      def calibration_caps
        { "timeout_seconds" => 100, "rss_cap_mib" => 1024, "as_cap_mib" => 2048 }
      end

      def calibration_provenance
        { "manifest_sha256" => "a" * 64, "emfsvg_revision" => "b" * 40,
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
        adapter = double("qualified synthetic adapter")
        allow(adapter).to receive_messages(snapshot: calibration_provenance, inputs: inputs,
                                           command: ["synthetic-child"],
                                           validate_report!: { "input_bytes" => 100, "output_bytes" => 150,
                                                               "warnings" => [], "exception" => nil })
        adapter
      end

      def calibration_document
        runner = double("bounded runner", run: calibration_report)
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
