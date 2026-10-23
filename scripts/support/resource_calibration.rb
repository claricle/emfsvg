# frozen_string_literal: true

require "json"
require "tempfile"
require "yaml"
require_relative "../check_parity_provenance"
require_relative "../../spec/support/bounded_conversion"

module Emfsvg
  module ResourceCalibration
    class Rejected < StandardError; end

    # No adapter is supplied until the released upstream public contracts can
    # prove warnings, typed failures and actual native selection. Metadata alone
    # cannot establish those facts, even if all manifest fields are populated.
    class Prerequisites
      def self.verify!(manifest, _fixture_root)
        errors = ParityProvenance.new(manifest).errors
        data = YAML.safe_load_file(manifest)
        raise Rejected, "manifest must be a mapping" unless data.is_a?(Hash)

        { "diagnostics" => 65, "resources" => 66 }.each do |name, number|
          issue = data.dig("provenance", "upstream_contracts", name, "issue")
          expected = "https://github.com/claricle/emf/issues/#{number}"
          errors << "#{name}: expected upstream issue #{expected}" unless issue == expected
        end
        errors << "Public calibration contract unavailable: exact corpus selection, " \
                  "loaded released runtime/package verification, and ruby/native/native-selected-auto " \
                  "production conformance must be implemented against landed upstream interfaces."
        raise Rejected, errors.join("\n")
      rescue TypeError, NoMethodError => e
        raise Rejected, "malformed prerequisite metadata: #{e.message}"
      end
    end

    class Limits
      KEYS = %w[timeout_seconds rss_cap_mib as_cap_mib].freeze
      MEASUREMENTS = %w[elapsed_seconds rss_peak_kib as_peak_kib].freeze

      def self.validate!(caps)
        raise Rejected, "all three explicit outer caps are required" unless caps.keys.sort == KEYS.sort

        caps.each_value do |value|
          unless value.is_a?(Numeric) && value.finite? && value.positive?
            raise Rejected,
                  "outer caps must be finite positive numbers"
          end
        end
        caps
      end

      def self.measurements!(samples)
        raise Rejected, "no calibration samples" if samples.empty?

        samples.map do |sample|
          raise Rejected, "unsafe child outcome" unless sample.fetch("safe") == true

          MEASUREMENTS.map do |key|
            value = sample.fetch(key)
            raise Rejected, "missing or invalid #{key}" unless value.is_a?(Numeric) && value.finite? && value.positive?

            value
          end
        end
      rescue KeyError => e
        raise Rejected, "incomplete measurement: #{e.message}"
      end

      def self.derive(samples, caps)
        validate!(caps)
        maxima = measurements!(samples).transpose.map(&:max)
        derived = { "timeout_seconds" => (maxima[0] * 4).ceil,
                    "rss_cap_mib" => ((maxima[1] * 2 / 1024.0) + 64).ceil,
                    "as_cap_mib" => ((maxima[2] * 2 / 1024.0) + 128).ceil }
        raise Rejected, "derived ceiling reaches an outer cap" if derived.any? { |key, value| value >= caps.fetch(key) }

        derived
      end
    end

    class Baseline
      VERSION = 1
      KEYS = %w[schema_version provenance inputs outer_caps grace_seconds repetitions samples derived_limits].freeze
      PROVENANCE = %w[manifest_sha256 emfsvg_revision runtime native_library selected_backend platform
                      enforcement].freeze
      SAMPLE = %w[case repetition input_bytes output_bytes warnings exception elapsed_seconds rss_peak_kib as_peak_kib
                  exitstatus signal safe mechanism].freeze

      def self.validate_observations!(document)
        raise Rejected, "unknown calibration schema" unless document.is_a?(Hash) && document.keys.sort == KEYS.sort &&
                                                            document["schema_version"] == VERSION

        provenance = document.fetch("provenance")
        raise Rejected, "incomplete provenance" unless provenance.is_a?(Hash) && provenance.keys.sort == PROVENANCE.sort

        validate_provenance!(provenance)
        raise Rejected, "three repetitions are required" unless document["repetitions"] == 3

        grace = document["grace_seconds"]
        raise Rejected, "invalid TERM grace interval" unless grace.is_a?(Numeric) && grace.finite? && grace.positive?

        validate_samples!(document)
        Limits.validate!(document.fetch("outer_caps"))
        Limits.measurements!(document.fetch("samples"))

        document
      rescue KeyError, TypeError, NoMethodError => e
        raise Rejected, "invalid baseline: #{e.message}"
      end

      def self.validate!(document)
        validate_observations!(document)
        expected = Limits.derive(document.fetch("samples"), document.fetch("outer_caps"))
        raise Rejected, "derivation drift" unless expected == document.fetch("derived_limits")

        document
      end

      def self.validate_provenance!(provenance)
        { "manifest_sha256" => ParityProvenance::SHA256,
          "emfsvg_revision" => ParityProvenance::REVISION }.each do |key, pattern|
          raise Rejected, "invalid #{key}" unless provenance[key].is_a?(String) && pattern.match?(provenance[key])
        end
        { "runtime" => %w[version package_sha256 source_revision],
          "native_library" => %w[artifact_sha256 source_revision abi],
          "platform" => %w[os architecture ruby], "enforcement" => %w[rss address_space time] }.each do |key, fields|
          values = provenance.fetch(key)
          unless values.is_a?(Hash) && fields.all? { |field| values[field].is_a?(String) && !values[field].empty? }
            raise Rejected, "incomplete #{key} provenance"
          end
        end
        return if provenance["selected_backend"] == "native" && provenance.dig("platform", "os") == "linux"

        raise Rejected, "authoritative native Linux calibration is required"
      end

      def self.validate_samples!(document)
        inputs = document.fetch("inputs")
        raise Rejected, "no pinned inputs" unless inputs.is_a?(Array) && !inputs.empty?

        names = inputs.map { |input| input.fetch("name") }
        inputs.each { |input| validate_input!(input) }
        raise Rejected, "duplicate inputs" unless names.uniq == names

        samples = document.fetch("samples")
        expected = names.flat_map { |name| (1..3).map { |rep| [name, rep] } }
        actual = samples.map do |sample|
          validate_sample!(sample, document.dig("provenance", "enforcement"))

          [sample.fetch("case"), sample.fetch("repetition")]
        end
        raise Rejected, "sample coverage/order drift" unless actual == expected
      end

      def self.validate_input!(input)
        valid = input.keys.sort == %w[expected_outcome name sha256] && input["name"].is_a?(String) &&
                input["sha256"].is_a?(String) && ParityProvenance::SHA256.match?(input["sha256"]) &&
                input["expected_outcome"].is_a?(Hash) && !input["expected_outcome"].empty?
        raise Rejected, "incomplete pinned input" unless valid
      end

      def self.validate_sample!(sample, enforcement)
        raise Rejected, "incomplete child report" unless sample.keys.sort == SAMPLE.sort

        counts = sample.values_at("input_bytes", "output_bytes")
        valid = counts.all? { |value| value.is_a?(Integer) && value >= 0 } && sample["warnings"].is_a?(Array) &&
                (sample["exception"].nil? || sample["exception"].is_a?(Hash)) &&
                sample["exitstatus"].eql?(0) && sample["signal"].nil? && sample["mechanism"] == enforcement
        raise Rejected, "invalid child outcome" unless valid
      end

      def self.write!(path, document)
        validate!(document)
        Tempfile.create([".resource-calibration-", ".yml"], File.dirname(File.expand_path(path))) do |file|
          # Remove object identity so safe_load can read the YAML without aliases.
          file.write(YAML.dump(JSON.parse(JSON.generate(document))))
          file.flush
          file.fsync
          file.close
          File.rename(file.path, path)
        end
      end

      def self.check!(baseline, current)
        validate!(baseline)
        # Fresh measurements use the stored ceilings; only stored samples determine their derivation.
        validate_observations!(current)
        pinned = KEYS - %w[samples]
        unless pinned.all? { |key| baseline.fetch(key) == current.fetch(key) }
          raise Rejected, "calibration provenance or input drift"
        end

        baseline.fetch("samples").zip(current.fetch("samples")).each do |stored, observed|
          fixed = SAMPLE - Limits::MEASUREMENTS
          raise Rejected, "calibration outcome drift" unless fixed.all? { |key| stored[key] == observed[key] }

          values = [observed.fetch("elapsed_seconds"), observed.fetch("rss_peak_kib") / 1024.0,
                    observed.fetch("as_peak_kib") / 1024.0]
          ceilings = baseline.fetch("derived_limits").values_at(*Limits::KEYS)
          unless values.zip(ceilings).all? { |value, cap| value <= cap }
            raise Rejected, "observed sample exceeds stored ceiling"
          end
        end

        current
      end
    end

    # The adapter must verify actual public contracts before returning a pinned
    # snapshot/inputs, and validate each public conversion report. Production has
    # no adapter yet; tests supply one without invoking a corpus or native code.
    class Session
      GRACE_SECONDS = 0.2

      def initialize(adapter:, caps:, runner: SpecSupport::BoundedConversion)
        @adapter = adapter
        @caps = Limits.validate!(caps)
        @runner = runner
      end

      def collect(stored_limits: nil)
        before = JSON.parse(JSON.generate(@adapter.snapshot))
        inputs = JSON.parse(JSON.generate(@adapter.inputs))
        samples = inputs.flat_map { |input| (1..3).map { |rep| sample(input, rep) } }
        unless before == @adapter.snapshot && inputs == @adapter.inputs
          raise Rejected,
                "input or provenance changed during calibration"
        end

        document = { "schema_version" => Baseline::VERSION, "provenance" => before, "inputs" => inputs,
                     "outer_caps" => @caps, "grace_seconds" => GRACE_SECONDS, "repetitions" => 3, "samples" => samples,
                     "derived_limits" => stored_limits || Limits.derive(samples, @caps) }
        stored_limits ? Baseline.validate_observations!(document) : Baseline.validate!(document)
      end

      def execute(mode:, path:, output: $stdout)
        existing = Baseline.validate!(YAML.safe_load_file(path)) if mode == "check"
        raise Rejected, "mode must be generate or check" unless %w[generate check].include?(mode)

        verify_pinned!(existing) if existing
        @run_caps = existing ? existing.fetch("derived_limits") : @caps
        document = collect(stored_limits: existing&.fetch("derived_limits"))
        if mode == "check"
          Baseline.check!(existing, document)
        else
          Baseline.write!(path, document)
        end
        output.puts "#{path}: #{document.fetch('inputs').size} cases, 3 repetitions, zero unsafe outcomes; " \
                    "ceilings #{(existing || document).fetch('derived_limits').to_json}"
        output.puts "Observed samples: #{document.fetch('samples').to_json}" if mode == "check"
        document
      end

      private

      def verify_pinned!(baseline)
        unless baseline.fetch("outer_caps") == @caps && baseline.fetch("grace_seconds") == GRACE_SECONDS &&
               baseline.fetch("provenance") == @adapter.snapshot && baseline.fetch("inputs") == @adapter.inputs
          raise Rejected, "calibration provenance, input or outer-cap drift before execution"
        end
      end

      def sample(input, repetition)
        caps = @run_caps || @caps
        report = @runner.run(command: @adapter.command(input), basename: input.fetch("name"),
                             timeout_seconds: caps.fetch("timeout_seconds"), rss_cap_mib: caps.fetch("rss_cap_mib"),
                             as_cap_mib: caps.fetch("as_cap_mib"), grace_seconds: GRACE_SECONDS, authoritative: true)
        unless report[:success] && report[:breach].nil? && report[:status] == :exited && report[:signal].nil?
          raise Rejected, "unsafe child outcome for #{input.fetch('name')}"
        end

        conversion = @adapter.validate_report!(input, report)
        { "case" => input.fetch("name"), "repetition" => repetition, **conversion,
          "elapsed_seconds" => report.fetch(:elapsed_seconds),
          "rss_peak_kib" => report.fetch(:metrics).fetch(:rss_peak_kib),
          "as_peak_kib" => report.fetch(:metrics).fetch(:as_peak_kib), "exitstatus" => report.fetch(:exitstatus),
          "signal" => report.fetch(:signal), "safe" => true, "mechanism" => report.fetch(:mechanism) }
      rescue KeyError => e
        raise Rejected, "incomplete child report: #{e.message}"
      end
    end
  end
end
