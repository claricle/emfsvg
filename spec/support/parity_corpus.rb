# frozen_string_literal: true

require "digest"
require "open3"
require "pathname"
require "yaml"

module Emfsvg
  module SpecSupport
    # External corpus data is independent of the emf code loaded by Bundler.
    class ParityCorpus
      class SetupError < StandardError; end

      PROJECT_ROOT = File.expand_path("../..", __dir__)
      MANIFEST_PATH = File.join(PROJECT_ROOT, "spec/fixtures/parity_manifest.yml")
      GROUP_COUNTS = { "golden" => 208, "round_trip" => 209, "compatibility" => 426 }.freeze
      COMPOSITION = { "ruby_to_c_golden" => 208, "c_artifact_integrity" => 208,
                      "fixed_sample" => 9, "aggregate_inventory" => 1 }.freeze

      ENTRY_KINDS = %w[source golden round_trip].freeze

      attr_reader :manifest, :root

      def initialize(root: ENV.fetch("EMF_FIXTURE_ROOT", nil), manifest_path: MANIFEST_PATH, project_root: PROJECT_ROOT)
        @manifest = YAML.safe_load_file(manifest_path)
        @root = root && File.expand_path(root)
        @project_root = File.expand_path(project_root)
      rescue Psych::Exception, SystemCallError => e
        raise SetupError, "Cannot read parity manifest: #{e.message}"
      end

      def fixtures
        manifest.fetch("fixtures")
      end

      def corrupted
        manifest.fetch("corrupted")
      end

      def source_paths
        verify!
        fixtures.map { |entry| source_path(entry) }
      end

      def source_path(entry)
        checked_path(root, entry.fetch("source").fetch("path"))
      end

      def artifact_path(entry, kind)
        checked_path(@project_root, entry.fetch(kind).fetch("path"))
      end

      def verify!
        verify_schema!
        verify_revision!
        verify_sources!
        verify_artifacts!
        verify_inventories!
        self
      rescue KeyError, TypeError, NoMethodError, Psych::Exception => e
        raise SetupError, "Invalid parity manifest: #{e.message}"
      end

      def inventory_digest(kinds)
        rows = fixtures.sort_by { |entry| entry.fetch("name") }.map do |entry|
          values = [entry.fetch("name")] + kinds.map { |kind| entry.fetch(kind).fetch("sha256") }
          "#{values.join("\t")}\n"
        end
        Digest::SHA256.hexdigest(rows.join)
      end

      private

      def verify_schema!
        fail_setup("unsupported schema") unless manifest.fetch("schema_version") == 1
        GROUP_COUNTS.each do |group, count|
          fail_setup("#{group} count must be #{count}") unless manifest.fetch("groups").fetch(group) == count
        end
        unless manifest.fetch("groups").fetch("compatibility_composition") == COMPOSITION
          fail_setup("compatibility composition must be 208/208/9/1")
        end
        fail_setup("expected 208 fixtures") unless fixtures.length == 208
        fail_setup("expected 21 corrupt fixtures") unless corrupted.length == 21
        [fixtures, corrupted].each do |entries|
          names = entries.map { |entry| entry.fetch("name") }
          fail_setup("duplicate basename") unless names.uniq == names
          entries.each { |entry| verify_entry!(entry) }
        end
        verify_sample!
      end

      def verify_sample!
        expected_sample = corpus.fetch("source_directories").zip([5, 3, 2]).flat_map do |directory, size|
          fixtures.select { |entry| File.dirname(entry.fetch("source").fetch("path")) == directory }
                  .sort_by { |entry| entry.fetch("name") }.first(size).map { |entry| entry.fetch("name") }
        end
        return if manifest.fetch("fixed_sample") == expected_sample && expected_sample.size == 9

        fail_setup("fixed historical sample mismatch")
      end

      def verify_entry!(entry)
        name = entry.fetch("name")
        fail_setup("invalid basename #{name.inspect}") unless name.is_a?(String) && File.basename(name) == name
        entry.each do |kind, value|
          next unless ENTRY_KINDS.include?(kind)

          path = value.fetch("path")
          extension = kind == "source" ? ".emf" : ".svg"
          fail_setup("basename/path mismatch for #{name}") unless File.basename(path) == "#{name}#{extension}"
          fail_setup("invalid SHA-256 for #{name}/#{kind}") unless /\A[0-9a-f]{64}\z/.match?(value.fetch("sha256"))
        end
      end

      def corpus
        manifest.fetch("provenance").fetch("corpus")
      end

      def verify_revision!
        fail_setup("set EMF_FIXTURE_ROOT to the pinned external emf checkout") unless root && File.directory?(root)
        revision = corpus.fetch("revision")
        fail_setup("corpus revision must be a full SHA") unless /\A[0-9a-f]{40}\z/.match?(revision)
        actual, error, status = Open3.capture3("git", "-C", root, "rev-parse", "HEAD")
        fail_setup("cannot read corpus revision: #{error.strip}") unless status.success?
        fail_setup("corpus revision #{actual.strip} differs from #{revision}") unless actual.strip == revision
      end

      def verify_sources!
        directories = corpus.fetch("source_directories") + [corpus.fetch("corrupt_directory")]
        expected = (fixtures + corrupted).map { |entry| entry.fetch("source").fetch("path") }.sort
        actual = directories.flat_map do |directory|
          Dir.glob(File.join(checked_path(root, directory), "*.emf")).map do |path|
            Pathname.new(path).relative_path_from(Pathname.new(root)).to_s
          end
        end.sort
        compare_inventory!("source", expected, actual)
        (fixtures + corrupted).each do |entry|
          verify_digest!(source_path(entry), entry.fetch("source").fetch("sha256"))
        end
      end

      def verify_artifacts!
        %w[golden round_trip].each do |kind|
          expected = fixtures.map { |entry| entry.fetch(kind).fetch("path") }.sort
          directory = kind == "golden" ? "golden" : "emfsvg_golden"
          actual = Dir.glob(File.join(@project_root, "spec/fixtures", directory, "*.svg")).map do |path|
            Pathname.new(path).relative_path_from(Pathname.new(@project_root)).to_s
          end.sort
          compare_inventory!(kind, expected, actual)
          fixtures.each { |entry| verify_digest!(artifact_path(entry, kind), entry.fetch(kind).fetch("sha256")) }
        end
      end

      def verify_inventories!
        { "round_trip_sha256" => ["round_trip"],
          "aggregate_sha256" => %w[source golden round_trip] }.each do |key, kinds|
          fail_setup("#{key} mismatch") unless inventory_digest(kinds) == manifest.fetch("inventories").fetch(key)
        end
      end

      def checked_path(base, relative)
        path = File.expand_path(relative, base)
        fail_setup("path escapes inventory root: #{relative}") unless path.start_with?("#{base}/")
        fail_setup("missing inventory path: #{relative}") unless File.exist?(path)
        unless File.realpath(path).start_with?("#{File.realpath(base)}/")
          fail_setup("symlink escapes inventory root: #{relative}")
        end
        path
      end

      def compare_inventory!(kind, expected, actual)
        return if expected == actual && expected.uniq == expected

        missing = (expected - actual).inspect
        unexpected = (actual - expected).inspect
        fail_setup("#{kind} inventory mismatch: missing=#{missing}, unexpected=#{unexpected}")
      end

      def verify_digest!(path, expected)
        return if File.file?(path) && Digest::SHA256.file(path).hexdigest == expected

        fail_setup("SHA-256 mismatch: #{path}")
      end

      def fail_setup(message)
        raise SetupError, "Parity setup: #{message}. See spec/fixtures/README.adoc."
      end
    end
  end
end
