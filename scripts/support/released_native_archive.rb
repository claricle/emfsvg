# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "released_qualification"

module Emfsvg
  # Verifies the registry archive before exporting its Linux library and attestation.
  module ReleasedNativeArchive
    PLATFORM = "x86_64-linux-gnu"
    ROOT = "lib/emf/native"

    def self.extract!(manifest_path, package_path, library_path, provenance_path)
      manifest = YAML.safe_load_file(manifest_path).fetch("provenance")
      native = manifest.fetch("native_library")
      runtime = manifest.fetch("runtime")
      unless Digest::SHA256.file(package_path).hexdigest == native.fetch("package_sha256")
        reject!("native package SHA mismatch")
      end
      package = Gem::Package.new(package_path)
      spec = package.spec
      valid = spec.name == "emf" && spec.version.to_s == runtime.fetch("version") && spec.platform.to_s == PLATFORM
      reject!("native package name, version or platform mismatch") unless valid

      Dir.mktmpdir("released-native-") do |directory|
        package.extract_files(directory)
        library = verified_library(directory, runtime, native)
        FileUtils.cp(library, library_path)
        File.write(provenance_path, JSON.generate(native.slice("artifact_sha256", "source_revision", "abi")))
      end
      spec.full_name
    rescue KeyError, JSON::ParserError => e
      reject!("incomplete native package evidence: #{e.message}")
    end

    def self.verified_library(directory, runtime, native)
      root = File.join(directory, ROOT)
      provenance = JSON.parse(File.read(File.join(root, "provenance.json")))
      platform = JSON.parse(File.read(File.join(root, "platforms.json")))
      library = File.join(root, PLATFORM, "libemf_ffi.so")
      digest = Digest::SHA256.file(library).hexdigest
      valid = provenance.fetch("platform") == PLATFORM && provenance.fetch("target") == "x86_64-unknown-linux-gnu" &&
              provenance.fetch("gem_version") == runtime.fetch("version") &&
              provenance.fetch("revision") == runtime.fetch("source_revision") &&
              provenance.fetch("revision") == native.fetch("source_revision") &&
              provenance.fetch("library_sha256") == digest && digest == native.fetch("artifact_sha256") &&
              platform.fetch("platform") == PLATFORM && platform.fetch("library") == "libemf_ffi.so" &&
              platform.fetch("sha256") == digest && platform.fetch("abi_version").to_s == native.fetch("abi")
      reject!("native package embedded identity mismatch") unless valid

      library
    end

    def self.reject!(message)
      raise ReleasedQualification::Rejected, message
    end
    private_class_method :verified_library, :reject!
  end
end
