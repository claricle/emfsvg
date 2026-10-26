# frozen_string_literal: true

require_relative "../../scripts/support/released_native_archive"
require_relative "released_qualification_fixture"

module Emfsvg
  module SpecSupport
    module ReleasedNativeArchiveFixture
      include ReleasedQualificationFixture

      def build_native_archive(changes = {})
        root = File.join(@directory, "lib/emf/native")
        FileUtils.mkdir_p(File.join(root, "x86_64-linux-gnu"))
        File.binwrite(File.join(root, "x86_64-linux-gnu/libemf_ffi.so"), "native fixture bytes")
        digest = Digest::SHA256.hexdigest("native fixture bytes")
        revision = @manifest.dig("provenance", "runtime", "source_revision")
        provenance = { "platform" => "x86_64-linux-gnu", "target" => "x86_64-unknown-linux-gnu",
                       "gem_version" => "9.8.7", "revision" => revision, "library_sha256" => digest }
        platform = { "platform" => "x86_64-linux-gnu", "library" => "libemf_ffi.so", "sha256" => digest,
                     "abi_version" => 1 }
        File.write(File.join(root, "provenance.json"), JSON.generate(provenance.merge(changes.fetch(:provenance, {}))))
        File.write(File.join(root, "platforms.json"), JSON.generate(platform.merge(changes.fetch(:platform, {}))))
        spec = Gem::Specification.new do |gem|
          gem.name = "emf"
          gem.version = "9.8.7"
          gem.platform = changes.fetch(:gem_platform, "x86_64-linux-gnu")
          gem.summary = "Synthetic qualification fixture"
          gem.authors = ["Fixture"]
          gem.files = Dir.chdir(@directory) { Dir["lib/**/*"].select { |path| File.file?(path) } }
        end
        path = File.join(@directory, "native.gem")
        Dir.chdir(@directory) { Gem::Package.build(spec, true, false, path) }
        @manifest.fetch("provenance").fetch("native_library").merge!(
          "package_sha256" => Digest::SHA256.file(path).hexdigest,
          "artifact_sha256" => digest, "source_revision" => revision
        )
        write_release_manifest(@manifest)
        path
      end
    end
  end
end
