# frozen_string_literal: true

require "digest"
require "json"
require "rbconfig"
require "rubygems/package"
require "tmpdir"
require_relative "calibration_qualification_inventory"
require_relative "calibration_production_adapter"

module Emfsvg
  module ResourceCalibration
    class Qualification
      BACKENDS = %w[ruby native auto].freeze
      CAPS = { timeout_seconds: 30, rss_cap_mib: 512, as_cap_mib: 2048, grace_seconds: 0.2,
               authoritative: false }.freeze

      def initialize(manifest:, fixture_root:, ledger_path: nil, package_path: ENV.fetch("EMF_RELEASE_PACKAGE", nil),
                     native_library: ENV.fetch("EMF_NATIVE_LIBRARY",
                                               nil), native_provenance_path: ENV.fetch("EMF_NATIVE_PROVENANCE", nil),
                     lockfile: File.expand_path("../../Gemfile.lock", __dir__), runner: SpecSupport::BoundedConversion)
        @manifest = File.realpath(manifest)
        @manifest_sha = digest(@manifest)
        @data = YAML.safe_load_file(@manifest)
        @root = File.realpath(fixture_root)
        @ledger_path = ledger_path || File.join(File.dirname(@manifest), "reviewed_corrupt_outcomes.json")
        @package_path = package_path
        @native = native_library
        @native_provenance_path = native_provenance_path
        @lockfile = lockfile
        @runner = runner
      end

      def verify!
        @ledger_sha = digest(@ledger_path)
        @inputs = QualificationInventory.new(@data, JSON.parse(File.read(@ledger_path))).inputs
        require_artifacts!
        verify_package_sha!
        verify_native!(check_abi: false)
        @identity = run_json([RbConfig.ruby, File.expand_path("calibration_qualification_probe.rb", __dir__),
                              @lockfile, @native], "runtime-identity")
        verify_runtime!
        verify_native!
        adapter = ProductionAdapter.new(fixture_root: @root, inputs: @inputs, provenance: method(:snapshot),
                                        runtime_entrypoint: @identity.fetch("entrypoint"), native_library: @native)
        conformance!(adapter)
        adapter
      rescue CorruptOutcomeContract::Rejected, JSON::ParserError, KeyError, TypeError, NoMethodError,
             SystemCallError, Gem::Package::Error => e
        raise Rejected, "qualification evidence rejected: #{e.message}"
      end

      private

      def digest(path)
        Digest::SHA256.file(path).hexdigest
      end

      def require_artifacts!
        [@package_path, @native, @native_provenance_path, @lockfile].each do |path|
          raise Rejected, "explicit released package, native artifact/provenance and lockfile are required" unless
            path.is_a?(String) && File.file?(path)
        end
        @native = File.realpath(@native)
        @lock_sha = digest(@lockfile)
        @native_provenance_sha = digest(@native_provenance_path)
      end

      def verify_runtime!
        expected = @data.dig("provenance", "runtime")
        verify_package_sha!
        raise Rejected, "loaded runtime version mismatch" unless @identity.fetch("version") == expected.fetch("version")

        package = Gem::Package.new(@package_path)
        spec = package.spec
        unless spec.name == "emf" && spec.version.to_s == expected.fetch("version")
          raise Rejected, "released archive name/version mismatch"
        end

        revision = spec.metadata["source_revision"]
        if revision && revision != expected.fetch("source_revision")
          raise Rejected, "released archive source revision mismatch"
        end

        verify_installed_files!(package)
      end

      def verify_package_sha!
        expected = @data.dig("provenance", "runtime", "package_sha256")
        raise Rejected, "released package SHA mismatch" unless digest(@package_path) == expected
      end

      def verify_installed_files!(package)
        root = File.realpath(@identity.fetch("root"))
        unless File.realpath(@identity.fetch("entrypoint")) == File.join(root, "lib/emf.rb") &&
               digest(@identity.fetch("entrypoint")) == @identity.fetch("sha256")
          raise Rejected, "loaded runtime entrypoint mismatch"
        end

        Dir.mktmpdir("emf-release-verification") do |directory|
          package.extract_files(directory)
          files = Dir.glob("**/*", File::FNM_DOTMATCH, base: directory).select { |name| File.file?(File.join(directory, name)) }
          raise Rejected, "release archive has no emf entrypoint" unless files.include?("lib/emf.rb")

          files.each do |name|
            installed = File.realpath(File.join(root, name))
            unless installed.start_with?("#{root}/") && digest(installed) == digest(File.join(directory, name))
              raise Rejected, "installed release file mismatch: #{name}"
            end
          end
        end
      end

      def verify_native!(check_abi: true)
        expected = @data.dig("provenance", "native_library").slice("artifact_sha256", "source_revision", "abi")
        attestation = JSON.parse(File.read(@native_provenance_path))
        abi_matches = !check_abi || @identity.fetch("abi") == expected.fetch("abi")
        return if attestation == expected && digest(@native) == expected.fetch("artifact_sha256") && abi_matches

        raise Rejected, "native artifact/source/ABI mismatch"
      end

      def run_json(command, name)
        report = @runner.run(command: command, basename: name, **CAPS)
        unless report[:success] == true && report[:breach].nil? && report[:stderr] == "" && report[:signal].nil? &&
               report[:status] == :exited && report[:exitstatus].eql?(0)
          raise Rejected, "bounded qualification child failed: #{name}"
        end

        mechanism = report.fetch(:mechanism).transform_keys(&:to_s).transform_values(&:to_s)
        raise Rejected, "qualification enforcement drift" if @mechanism && @mechanism != mechanism

        @mechanism = mechanism
        JSON.parse(report.fetch(:stdout))
      end

      def conformance!(adapter)
        adapter.inputs.each do |input|
          BACKENDS.each do |backend|
            command = adapter.command(input)
            # The adapter is deliberately auto-only. Its command's final four
            # arguments are the public bootstrap protocol, backend first.
            command[-4] = backend
            value = run_json(command, "#{backend}-#{File.basename(input.fetch('name'))}")
            adapter.command(input) # Recheck source bytes after conversion.
            verify_native!
            validate_identity!(input, backend, value)
            if backend == "auto"
              adapter.validate_report!(input, { stdout: JSON.generate(value), stderr: "" })
            else
              validate_outcome!(input, value)
            end
          end
        end
      end

      def validate_identity!(input, backend, value)
        selection = { "selected" => backend == "ruby" ? "ruby" : "native",
                      "method" => "Emf.backend", "public_contract" => true }
        runtime = @identity.slice("entrypoint", "sha256", "version")
        valid = value["schema_version"] == 1 && value["runtime"] == runtime && value["backend"] == backend &&
                value["input_sha256"] == input.fetch("sha256") &&
                value["input_bytes"] == File.size(File.join(@root, input.fetch("name"))) &&
                value["native_sha256"] == digest(@native) &&
                value["selection_before"] == selection && value["selection_after"] == selection
        raise Rejected, "public #{backend} conformance identity/selection mismatch" unless valid
      end

      def validate_outcome!(input, value)
        source = { "path" => input.fetch("name"), "sha256" => input.fetch("sha256") }
        record = { "reviewed" => true, "source" => source, "expected_outcome" => input.fetch("expected_outcome"),
                   "evidence" => [{ "kind" => "reference", "reference" => @manifest }] }
        manifest = { "corrupted" => [{ "name" => "selected", "source" => source }] }
        contract = CorruptOutcomeContract.new(manifest: manifest, ledger: { "selected" => record })
        contract.validate_observation!("selected", value.merge("source" => source))
      end

      def snapshot
        unless digest(@manifest) == @manifest_sha && digest(@lockfile) == @lock_sha &&
               digest(@ledger_path) == @ledger_sha &&
               digest(@native_provenance_path) == @native_provenance_sha
          raise Rejected, "qualification evidence drift"
        end

        verify_runtime!
        verify_native!
        { "manifest_sha256" => @manifest_sha, "emfsvg_revision" => source_revision,
          "runtime" => @data.dig("provenance", "runtime").slice("version", "package_sha256", "source_revision"),
          "native_library" => @data.dig("provenance", "native_library").slice(
            "artifact_sha256", "source_revision", "abi"
          ),
          "selected_backend" => "native", "platform" => {
                                            "os" => RUBY_PLATFORM.include?("linux") ? "linux" : RUBY_PLATFORM,
                                            "architecture" => RbConfig::CONFIG.fetch("host_cpu"), "ruby" => RUBY_VERSION
                                          },
          "enforcement" => @mechanism }
      end

      def source_revision
        IO.popen(["git", "-C", File.expand_path("../..", __dir__), "rev-parse", "HEAD"], &:read).strip
      end
    end
  end
end
