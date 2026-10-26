# frozen_string_literal: true

require_relative "calibration_qualification"
require_relative "source_qualification_probe"

module Emfsvg
  module ResourceCalibration
    # Prerelease evidence only: never accepted by the released baseline gate.
    class SourceQualification < Qualification
      def verify!
        raise Rejected, "source qualification requires Linux" unless RUBY_PLATFORM.include?("linux")

        @revision = @data.dig("provenance", "runtime", "source_revision")
        unless @revision.is_a?(String) && @revision.match?(/\A[0-9a-f]{40}\z/)
          raise Rejected, "source qualification requires a full runtime revision"
        end

        @ledger_sha = digest(@ledger_path)
        @inputs = QualificationInventory.new(@data, JSON.parse(File.read(@ledger_path))).inputs
        [@native, @native_provenance_path, @lockfile].each do |path|
          raise Rejected, "explicit native artifact/provenance and lockfile required" unless path && File.file?(path)
        end
        @native = File.realpath(@native)
        @lock_sha = digest(@lockfile)
        @native_provenance_sha = digest(@native_provenance_path)
        @identity = run_json([RbConfig.ruby, File.expand_path("source_qualification_probe.rb", __dir__),
                              @lockfile, @native, @revision], "source-runtime-identity")
        verify_runtime!
        verify_native!
        adapter = ProductionAdapter.new(fixture_root: @root, inputs: @inputs, provenance: method(:snapshot),
                                        runtime_entrypoint: @identity.fetch("entrypoint"), native_library: @native)
        conformance!(adapter)
        adapter
      rescue CorruptOutcomeContract::Rejected, JSON::ParserError, KeyError, TypeError, NoMethodError,
             SystemCallError => e
        raise Rejected, "source qualification evidence rejected: #{e.message}"
      end

      private

      def qualification_caps
        CAPS.merge(authoritative: true)
      end

      def verify_runtime!
        root = @identity.fetch("root")
        valid = @identity.fetch("source_revision") == @revision &&
                @identity.fetch("version") == @data.dig("provenance", "runtime", "version") &&
                File.realpath(@identity.fetch("entrypoint")) == File.join(File.realpath(root), "lib/emf.rb") &&
                digest(@identity.fetch("entrypoint")) == @identity.fetch("sha256") &&
                Emfsvg::SourceQualificationProbe.ruby_tree_sha256(root) == @identity.fetch("ruby_tree_sha256")
        raise Rejected, "pinned source runtime drift" unless valid
      end

      def verify_native!(check_abi: true)
        expected = { "artifact_sha256" => digest(@native), "source_revision" => @revision, "abi" => "1" }
        unless JSON.parse(File.read(@native_provenance_path)) == expected &&
               (!check_abi || @identity.fetch("abi") == "1")
          raise Rejected, "source native artifact/revision/ABI mismatch"
        end
      end

      def snapshot
        unless digest(@manifest) == @manifest_sha && digest(@ledger_path) == @ledger_sha &&
               digest(@lockfile) == @lock_sha && digest(@native_provenance_path) == @native_provenance_sha
          raise Rejected, "source qualification evidence drift"
        end

        verify_runtime!
        verify_native!
        { "scope" => "prerelease-source", "released_runtime_qualified" => false,
          "manifest_sha256" => @manifest_sha, "emfsvg_revision" => source_revision,
          "runtime" => @identity.slice("version", "source_revision", "ruby_tree_sha256"),
          "native_library" => JSON.parse(File.read(@native_provenance_path)),
          "selected_backend" => "native", "enforcement" => @mechanism,
          "platform" => { "ruby" => RUBY_VERSION, "platform" => RUBY_PLATFORM } }
      end
    end
  end
end
