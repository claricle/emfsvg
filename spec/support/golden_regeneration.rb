# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "tmpdir"
require "yaml"

module Emfsvg
  module SpecSupport
    # Stages a complete candidate before replacing either committed baseline.
    class GoldenRegeneration
      class Error < StandardError; end

      KINDS = { "golden" => "golden", "round_trip" => "emfsvg_golden" }.freeze

      # Keep this inode stable across promotions and process exits. Removing the
      # file would let a new writer lock a different inode while a waiter holds it.
      class FixtureLock
        def self.synchronize(parent)
          path = File.join(File.realpath(parent), ".golden-regeneration.lock")
          File.open(path, File::RDWR | File::CREAT, 0o600) do |lock|
            unless lock.flock(File::LOCK_EX | File::LOCK_NB)
              raise Error, "Another golden regeneration holds the fixture directory lock"
            end

            yield
          end
        end
      end

      # Renames are individually atomic. Cooperating writers must hold the same
      # directory lock; readers must not run during promotion. A process/host crash
      # can require manual recovery from the retained transaction directory.
      class Promotion
        def initialize(pairs, backup_root)
          @pairs = pairs
          @backup_root = backup_root
        end

        def run
          moved = []
          @pairs.each_with_index do |(candidate, target), index|
            backup = File.join(@backup_root, "backup-#{index}")
            File.rename(target, backup)
            moved << [target, backup]
            File.rename(candidate, target)
          end
        rescue StandardError => e
          begin
            moved.reverse_each do |target, backup|
              FileUtils.rm_rf(target)
              File.rename(backup, target)
            end
          rescue StandardError => rollback_error
            raise Error, "Promotion failed: #{e.message}; rollback failed: #{rollback_error.message}; " \
                         "recover backups in #{@backup_root}"
          end
          raise Error, "Promotion failed; original artifacts restored: #{e.message}"
        end
      end

      def initialize(corpus:, project_root:, manifest_path:, reference:, renderer:, svg_to_emf:, output: $stdout)
        @corpus = corpus
        @project_root = project_root
        @manifest_path = manifest_path
        @reference = reference
        @renderer = renderer
        @svg_to_emf = svg_to_emf
        @output = output
      end

      def run(check: false)
        @corpus.verify!
        verify_committed_inventory!
        verify_reference_provenance! unless check
        parent = File.join(@project_root, "spec/fixtures")
        FixtureLock.synchronize(parent) { run_locked(parent, check) }
      end

      private

      def verify_reference_provenance!
        provenance = @corpus.manifest.fetch("provenance").fetch("c_reference")
        revision = provenance.fetch("source_revision", nil)
        binary_digest = provenance.fetch("binary_sha256", nil)
        binary = ENV.fetch("EMF2SVG_REF_PATH", nil)
        valid = provenance["status"] == "verified" && /\A[0-9a-f]{40}\z/.match?(revision.to_s) &&
                /\A[0-9a-f]{64}\z/.match?(binary_digest.to_s) && binary && File.file?(binary) &&
                Digest::SHA256.file(binary).hexdigest == binary_digest && !provenance["build_recipe"].to_s.strip.empty?
        return if valid

        raise Error, "Promotion requires verified c_reference provenance: source_revision, build_recipe and " \
                     "binary_sha256 matching EMF2SVG_REF_PATH; " \
                     "historical unverified provenance cannot qualify new artifacts"
      end

      def run_locked(parent, check)
        original = baseline_digest
        staging = Dir.mktmpdir(".golden-regeneration-", check ? nil : parent)
        begin
          generate(staging)
          verify_candidates!(staging)
          @corpus.verify!
          verify_committed_inventory!
          changes = differences(staging)
          report(changes, check)
          return changes.empty? if check

          if changes.any? { |change| change.fetch(:group) == "round_trip" }
            raise Error, "Frozen round-trip artifacts changed; fix SVG -> EMF -> SVG conversion before promotion. " \
                         "Replacement baseline seeds require an explicit reviewed policy."
          end

          unless original == baseline_digest
            raise Error,
                  "Committed baseline changed during generation; retry with exclusive access"
          end

          verify_reference_provenance!
          promote(staging)
          true
        ensure
          # A failed rollback retains backups for explicit recovery.
          FileUtils.remove_entry(staging) if File.directory?(staging) && Dir.glob("#{staging}/backup-*").none?
        end
      end

      def generate(staging)
        KINDS.each_value { |directory| FileUtils.mkdir_p(File.join(staging, directory)) }
        @corpus.fixtures.each do |entry|
          KINDS.each_key do |kind|
            path = candidate_path(staging, entry, kind)
            bytes = generate_artifact(entry, kind)
            unless bytes.is_a?(String) && !bytes.empty?
              raise Error,
                    "#{kind} conversion produced no SVG for #{entry.fetch('name')}"
            end

            File.binwrite(path, bytes)
          rescue StandardError => e
            raise Error, "#{kind} conversion failed for #{entry.fetch('name')}: #{e.message}"
          end
        end
      end

      def generate_artifact(entry, kind)
        return @reference.call(@corpus.source_path(entry)) if kind == "golden"

        frozen_svg = File.binread(@corpus.artifact_path(entry, "round_trip"))
        @renderer.call(@svg_to_emf.call(frozen_svg))
      end

      def verify_committed_inventory!
        KINDS.each do |kind, directory|
          expected = @corpus.fixtures.map { |entry| "#{entry.fetch('name')}.svg" }.sort
          actual = Dir.children(File.join(@project_root, "spec/fixtures", directory)).sort
          next if actual == expected

          raise Error,
                "#{kind} committed inventory mismatch: missing=#{expected - actual}, unexpected=#{actual - expected}"
        end
      end

      def verify_candidates!(staging)
        KINDS.each do |kind, directory|
          expected = @corpus.fixtures.map { |entry| "#{entry.fetch('name')}.svg" }.sort
          actual = Dir.children(File.join(staging, directory)).sort
          next if expected == actual && expected.uniq == expected

          raise Error,
                "#{kind} candidate inventory mismatch: missing=#{expected - actual}, unexpected=#{actual - expected}"
        end
      end

      def differences(staging)
        @corpus.fixtures.flat_map do |entry|
          KINDS.filter_map do |kind, _directory|
            path = @corpus.artifact_path(entry, kind)
            expected = File.binread(path)
            generated = File.binread(candidate_path(staging, entry, kind))
            next if expected == generated

            offset = (0...[expected.bytesize, generated.bytesize].min).find do |index|
              expected.getbyte(index) != generated.getbyte(index)
            end
            { group: kind, basename: entry.fetch("name"), reference: path,
              expected_sha256: Digest::SHA256.hexdigest(expected), generated_sha256: Digest::SHA256.hexdigest(generated),
              first_different_byte: offset || [expected.bytesize, generated.bytesize].min }
          end
        end
      end

      def report(changes, check)
        command = "bundle exec ruby scripts/regenerate_golden.rb #{check ? '--check' : '--write'}"
        summary = {
          mode: check ? "check" : "promote", provenance: @corpus.manifest.fetch("provenance"),
          commands: { regeneration: command,
                      reference: [ENV.fetch("EMF2SVG_REF_PATH", nil), "INPUT.emf", "OUTPUT.svg"],
                      round_trip: "Emfsvg.from_bytes(Emfsvg.from_svg(File.binread(FROZEN_ROUND_TRIP.svg)))" },
          groups: @corpus.manifest.fetch("groups"),
          changed_basenames: changes.map { |change| change.fetch(:basename) }.uniq.sort,
          differences: changes.first(10), difference_count: changes.length,
          omitted_difference_count: [changes.length - 10, 0].max,
          promotion_limit: "Rollback on ordinary errors; cooperating writers only. " \
                           "Readers must stop during promotion; " \
                           "process or host failure can require manual backup recovery."
        }
        @output.puts(JSON.pretty_generate(summary))
      end

      def promote(staging)
        manifest = candidate_manifest(staging)
        candidate = File.join(staging, "manifest.yml")
        File.write(candidate, YAML.dump(manifest))
        pairs = KINDS.values.map do |directory|
          [File.join(staging, directory), File.join(@project_root, "spec/fixtures", directory)]
        end
        pairs << [candidate, @manifest_path]
        Promotion.new(pairs, staging).run
        Dir.glob("#{staging}/backup-*").each { |path| FileUtils.rm_rf(path) }
      end

      def candidate_manifest(staging)
        manifest = Marshal.load(Marshal.dump(@corpus.manifest))
        manifest.fetch("fixtures").each do |entry|
          KINDS.each_key { |kind| entry.fetch(kind)["sha256"] = Digest::SHA256.file(candidate_path(staging, entry, kind)).hexdigest }
        end
        { "round_trip_sha256" => ["round_trip"],
          "aggregate_sha256" => %w[source golden round_trip] }.each do |key, kinds|
          rows = manifest.fetch("fixtures").sort_by { |entry| entry.fetch("name") }.map do |entry|
            "#{([entry.fetch('name')] + kinds.map { |kind| entry.fetch(kind).fetch('sha256') }).join("\t")}\n"
          end
          manifest.fetch("inventories")[key] = Digest::SHA256.hexdigest(rows.join)
        end
        manifest
      end

      def candidate_path(staging, entry, kind)
        File.join(staging, KINDS.fetch(kind), "#{entry.fetch('name')}.svg")
      end

      def baseline_digest
        paths = @corpus.fixtures.flat_map { |entry| KINDS.keys.map { |kind| @corpus.artifact_path(entry, kind) } }
        paths << @manifest_path
        paths.map { |path| [path, Digest::SHA256.file(path).hexdigest] }
      end
    end
  end
end
