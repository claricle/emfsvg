# frozen_string_literal: true

require "digest"
require "fiddle"
require "json"
require "rubygems"

module Emfsvg
  class InstalledSourceContractProbe
    def self.call(gem_home, expected_revision, fixture_path, expected_native_sha256 = nil)
      raise "expected revision must be a full lowercase Git SHA" unless expected_revision.match?(/\A[0-9a-f]{40}\z/)
      raise "EMF_NATIVE_LIBRARY override is forbidden" if ENV.key?("EMF_NATIVE_LIBRARY")

      spec, root, revision = installed_spec(gem_home)
      raise "installed emf source revision mismatch" unless revision == expected_revision

      require File.join(root, "lib/emf")
      check_entrypoint(root)
      library_path, native_sha256 = installed_library(root, expected_native_sha256)
      previous_backend = ENV.fetch("EMF_BACKEND", nil)
      begin
        selections = %w[native auto].to_h do |mode|
          ENV["EMF_BACKEND"] = mode
          backend = Emf.backend
          raise "#{mode} backend did not select native" unless backend == :native

          diagnostic_smoke(fixture_path)
          [mode, backend.to_s]
        end
        resource_limit_smoke(library_path)
      ensure
        previous_backend ? ENV["EMF_BACKEND"] = previous_backend : ENV.delete("EMF_BACKEND")
      end

      { "version" => spec.version.to_s, "revision" => revision, "native_sha256" => native_sha256,
        "backends" => selections, "diagnostic" => "skipped-record-bytes-preserved",
        "resource_limit" => "input_bytes:87:88" }
    end

    def self.installed_spec(gem_home)
      specification_paths = Dir.glob(File.join(gem_home, "specifications", "emf-*.gemspec"))
      spec = specification_paths.filter_map { |path| Gem::Specification.load(path) }
                                .max_by(&:version)
      raise "emf gem is not installed in supplied GEM_HOME" unless spec

      root = File.expand_path(spec.full_gem_path)
      expected_root = File.join(File.expand_path(gem_home), "gems")
      raise "emf gem is outside supplied GEM_HOME" unless root.start_with?("#{expected_root}/")

      provenance = JSON.parse(File.read(File.join(root, "lib/emf/native/provenance.json")))
      metadata_revision = spec.metadata["source_revision"]
      provenance_revision = provenance["source_revision"] || provenance["revision"] || provenance["git_revision"]
      if metadata_revision && provenance_revision && metadata_revision != provenance_revision
        raise "installed emf provenance revision mismatch"
      end

      revision = metadata_revision || provenance_revision
      [spec, root, revision]
    end
    private_class_method :installed_spec

    def self.check_entrypoint(root)
      entrypoint = File.realpath($LOADED_FEATURES.find { |path| path.end_with?("/emf.rb") })
      raise "shadowed emf entrypoint" unless entrypoint == File.join(root, "lib/emf.rb")
    end
    private_class_method :check_entrypoint

    def self.installed_library(root, expected_sha256)
      native_root = File.join(root, "lib/emf/native")
      manifest = JSON.parse(File.read(File.join(native_root, "platforms.json")))
      path = File.realpath(File.join(native_root, manifest.fetch("platform"), manifest.fetch("library")))
      raise "native library is outside installed emf gem" unless path.start_with?("#{native_root}/")

      sha256 = Digest::SHA256.file(path).hexdigest
      raise "native library checksum mismatch" unless sha256 == manifest.fetch("sha256")
      raise "native library does not match expected checksum" if expected_sha256 && sha256 != expected_sha256

      [path, sha256]
    end
    private_class_method :installed_library

    def self.diagnostic_smoke(fixture_path)
      bytes = File.binread(fixture_path)
      header_size = bytes.unpack1("V", offset: 4)
      malformed = bytes.byteslice(0, header_size) + [27, 20].pack("V2")
      parsed = Emf.parse(malformed)
      diagnostic = parsed.diagnostics.fetch(0)
      valid = diagnostic.disposition == :skipped && diagnostic.record_index == 1 &&
              diagnostic.byte_offset == header_size && Emf.serialize(parsed) == malformed
      raise "native diagnostic/byte-preservation contract failed" unless valid
    end
    private_class_method :diagnostic_smoke

    # Uses the installed wrapper's error decoder through ordinary inherited calls.
    module NativeResourceProbe
      def verify_input_limit
        limits = Fiddle::Pointer[[48, 1].pack("L2") + [87, 128 * 1024 * 1024, 4 * 1024 * 1024,
                                                       640 * 1024 * 1024, 64 * 1024 * 1024].pack("Q5")]
        resource = "\0" * 88
        resource[0, 8] = [1, 88].pack("V2")
        resource[40, 4] = [0x464D4520].pack("V")
        document_with_limits(resource, limits) { raise "native resource limit was not enforced" }
      rescue Emf::ResourceLimitError => e
        valid = [e.resource, e.limit, e.actual] == [:input_bytes, 87, 88]
        raise "native resource metadata mismatch" unless valid
      end

      def document_with_limits(bytes, limits)
        output = slot
        checked(:emf_parse, bytes, bytes.bytesize, limits, output)
        yield pointer(output)
      ensure
        invoke(:emf_document_free, pointer(output)) if output && !pointer(output).zero?
      end
    end

    def self.resource_limit_smoke(library_path)
      loader_class = Class.new(Emf::Native::Loader) { include NativeResourceProbe }
      loader_class.new(library_path).verify_input_limit
    end
    private_class_method :resource_limit_smoke
  end
end

puts JSON.generate(Emfsvg::InstalledSourceContractProbe.call(*ARGV)) if $PROGRAM_NAME == __FILE__
