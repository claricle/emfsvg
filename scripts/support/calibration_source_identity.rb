# frozen_string_literal: true

require "digest"
require "open3"

module Emfsvg
  module ResourceCalibration
    # Hash working-tree bytes, including untracked implementation files. Baselines
    # and documentation are evidence, not executable inputs, and stay outside it.
    class SourceIdentity
      ROOT = File.expand_path("../..", __dir__)
      TREES = %w[lib scripts spec/support bin exe].freeze
      CONFIG = %w[Gemfile Gemfile.lock *.gemspec Rakefile .ruby-version .rspec .bundle/config
                  spec/spec_helper.rb spec/**/*_spec.rb].freeze
      PROSE = %w[.md .adoc .rdoc].freeze

      def self.snapshot(root: ROOT)
        revision, status = Open3.capture2("git", "-C", root, "rev-parse", "HEAD")
        raise Rejected, "cannot identify calibration source revision" unless status.success?

        { "emfsvg_revision" => revision.strip, "emfsvg_source_sha256" => digest(root) }
      rescue SystemCallError => e
        raise Rejected, "cannot identify calibration source: #{e.message}"
      end

      def self.digest(root)
        paths = TREES.flat_map { |tree| Dir.glob("#{tree}/**/*", File::FNM_DOTMATCH, base: root) }
        paths.concat(CONFIG.flat_map { |pattern| Dir.glob(pattern, base: root) })
        paths.select! { |path| File.file?(File.join(root, path)) && !PROSE.include?(File.extname(path)) }
        raise Rejected, "calibration implementation inputs are missing" if paths.empty?

        hash = Digest::SHA256.new
        hash << "emfsvg-calibration-source-v1\0"
        paths.uniq.sort.each do |path|
          full_path = File.join(root, path)
          bytes = File.binread(full_path)
          hash << "#{path.bytesize}:#{path}:#{File.stat(full_path).mode & 0o111}:#{bytes.bytesize}:" << bytes
        end
        hash.hexdigest
      end
    end
  end
end
