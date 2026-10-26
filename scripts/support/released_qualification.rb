# frozen_string_literal: true

require "bundler"
require "digest"
require "json"
require "rubygems/package"
require_relative "../check_parity_provenance"

module Emfsvg
  # Release-only boundary checks; public conversion qualification remains in ResourceCalibration.
  module ReleasedQualification
    class Rejected < StandardError; end

    GROUP_FILES = { "golden" => "golden_spec.rb", "round_trip" => "round_trip_golden_spec.rb",
                    "compatibility" => "compat_with_libemf2svg_spec.rb" }.freeze
    CORRUPT_EXAMPLE = "checks every declared corrupt input against qualified native Linux limits"

    def self.plan(manifest_path, lockfile)
      errors = ParityProvenance.new(manifest_path).errors
      raise Rejected, "reviewed released manifest required: #{errors.join('; ')}" unless errors.empty?

      manifest = YAML.safe_load_file(manifest_path)
      runtime = manifest.fetch("provenance").fetch("runtime")
      locked = Bundler::LockfileParser.new(File.read(lockfile)).specs.select { |spec| spec.name == "emf" }
      spec = locked.first
      valid = locked.one? && spec.source.is_a?(Bundler::Source::Rubygems) &&
              spec.source.remotes.map(&:to_s) == ["https://rubygems.org/"] &&
              spec.platform.to_s == "ruby" && spec.version.to_s == runtime.fetch("version")
      raise Rejected, "lock must select the reviewed emf version exclusively from https://rubygems.org/" unless valid

      { "package_url" => "https://rubygems.org/downloads/#{spec.full_name}.gem",
        "native_package_url" => "https://rubygems.org/downloads/emf-#{runtime.fetch('version')}-x86_64-linux-gnu.gem",
        "corpus_revision" => manifest.fetch("provenance").fetch("corpus").fetch("revision") }
    end

    def self.archive!(manifest_path, package_path)
      runtime = YAML.safe_load_file(manifest_path).fetch("provenance").fetch("runtime")
      raise Rejected, "released archive SHA mismatch" unless
        Digest::SHA256.file(package_path).hexdigest == runtime.fetch("package_sha256")

      spec = Gem::Package.new(package_path).spec
      valid = spec.name == "emf" && spec.platform.to_s == "ruby" && spec.version.to_s == runtime.fetch("version") &&
              spec.metadata["emf_revision"] == runtime.fetch("source_revision")
      raise Rejected, "released archive must attest the exact reviewed name, version and source_revision" unless valid

      spec.full_name
    end

    def self.acceptance!(manifest_path, report_path)
      manifest = YAML.safe_load_file(manifest_path)
      report = JSON.parse(File.read(report_path))
      examples = report.fetch("examples")
      summary = report.fetch("summary")
      validate_results!(examples, summary, manifest.fetch("baseline").fetch("whole_suite_examples"))

      GROUP_FILES.each do |group, filename|
        count = examples.count { |example| example.fetch("file_path") == "./spec/#{filename}" }
        unless count == manifest.fetch("groups").fetch(group)
          raise Rejected, "#{group} acceptance count drift: #{count}"
        end
      end
      corrupt = examples.select do |example|
        example.fetch("file_path") == "./spec/corrupted_resilience_spec.rb" &&
          example.fetch("description") == CORRUPT_EXAMPLE
      end
      raise Rejected, "real corrupted corpus qualification must execute exactly once" unless corrupt.one?

      true
    rescue KeyError, TypeError, NoMethodError, JSON::ParserError => e
      raise Rejected, "incomplete acceptance report: #{e.message}"
    end

    def self.validate_results!(examples, summary, minimum)
      clean = %w[failure_count pending_count errors_outside_of_examples_count].all? { |key| summary.fetch(key).zero? }
      valid = clean && examples.size >= minimum && summary.fetch("example_count") == examples.size &&
              examples.all? { |example| example.fetch("status") == "passed" } &&
              examples.map { |example| example.fetch("id") }.uniq.size == examples.size
      return if valid

      raise Rejected, "full acceptance requires every example passed, without omissions, skips or duplicates"
    end
    private_class_method :validate_results!
  end
end
