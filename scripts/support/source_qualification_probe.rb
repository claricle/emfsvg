# frozen_string_literal: true

require "bundler"
require "digest"
require "fiddle"
require "json"
require "open3"

module Emfsvg
  class SourceQualificationProbe
    SOURCE_URI = "https://github.com/claricle/emf.git"
    REQUIRED_EXPORTS = %w[emf_error_resource_view emf_document_snapshot_v3].freeze

    def self.call(lockfile, native_library, expected_revision)
      raise "expected revision must be a full lowercase Git SHA" unless expected_revision.match?(/\A[0-9a-f]{40}\z/)

      require "bundler/setup"
      require "emf"
      locked = Bundler::LockfileParser.new(Bundler.read_file(lockfile)).specs.select { |spec| spec.name == "emf" }
      loaded = Gem.loaded_specs.fetch("emf")
      unless locked.one? && git_source?(locked.first.source, expected_revision) &&
             loaded.source.is_a?(Bundler::Source::Git) && git_source?(loaded.source, expected_revision)
        raise "locked and loaded emf must use the expected Git source revision"
      end

      root = File.realpath(loaded.full_gem_path)
      entrypoint = File.realpath($LOADED_FEATURES.find { |path| path.end_with?("/emf.rb") })
      raise "shadowed emf entrypoint" unless entrypoint == File.join(root, "lib/emf.rb")
      raise "loaded emf root revision mismatch" unless git_revision(root) == expected_revision
      raise "loaded emf tracked tree is dirty" unless clean_tracked_tree?(root)

      library = Fiddle.dlopen(native_library)
      abi = Fiddle::Function.new(library["emf_abi_version"], [], Fiddle::TYPE_INT).call
      raise "native backend ABI version mismatch (expected 1)" unless abi == 1

      REQUIRED_EXPORTS.each { |name| library[name] }
      { "version" => loaded.version.to_s, "root" => root, "entrypoint" => entrypoint,
        "sha256" => Digest::SHA256.file(entrypoint).hexdigest, "abi" => abi.to_s,
        "source_revision" => expected_revision, "ruby_tree_sha256" => ruby_tree_sha256(root) }
    end

    def self.git_source?(source, revision)
      source.is_a?(Bundler::Source::Git) && source.uri == SOURCE_URI && source.ref == revision &&
        source.revision == revision
    end
    private_class_method :git_source?

    def self.git_revision(root)
      revision, status = Open3.capture2("git", "-C", root, "rev-parse", "HEAD")
      raise "unable to read loaded emf Git revision" unless status.success?

      revision.strip
    end
    private_class_method :git_revision

    def self.clean_tracked_tree?(root)
      system("git", "-C", root, "diff", "HEAD", "--exit-code", out: File::NULL, err: File::NULL)
    end
    private_class_method :clean_tracked_tree?

    def self.ruby_tree_sha256(root)
      digest = Digest::SHA256.new
      Dir.glob(File.join(root, "lib/**/*.rb")).each do |path|
        digest.update(path.delete_prefix("#{root}/"))
        digest.update("\0")
        digest.update(File.binread(path))
        digest.update("\0")
      end
      digest.hexdigest
    end
  end
end

puts JSON.generate(Emfsvg::SourceQualificationProbe.call(*ARGV)) if $PROGRAM_NAME == __FILE__
