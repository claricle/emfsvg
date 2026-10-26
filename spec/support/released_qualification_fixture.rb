# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "../../scripts/support/released_qualification"

module Emfsvg
  module SpecSupport
    module ReleasedQualificationFixture
      def release_manifest
        document = YAML.safe_load_file(ParityProvenance::DEFAULT_MANIFEST)
        document.fetch("provenance").fetch("runtime").merge!(
          "status" => "qualified", "source" => "rubygems", "version" => "9.8.7",
          "package_sha256" => "a" * 64
        )
        document.fetch("provenance").fetch("native_library").merge!(
          "status" => "qualified", "source_revision" => "b" * 40,
          "artifact_sha256" => "c" * 64, "abi" => "1"
        )
        document
      end

      def write_release_manifest(document)
        File.write(@manifest_path, YAML.dump(document))
      end

      def write_release_lock(source = "GEM\n  remote: https://rubygems.org/\n")
        File.write(@lockfile, "#{source}  specs:\n    emf (9.8.7)\n\nPLATFORMS\n  ruby\n\nDEPENDENCIES\n  emf\n")
      end

      def release_report
        examples = Emfsvg::ReleasedQualification::GROUP_FILES.flat_map do |group, filename|
          Array.new(@manifest.fetch("groups").fetch(group)) do |index|
            { "id" => "./spec/#{filename}[1:#{index}]", "file_path" => "./spec/#{filename}",
              "description" => "synthetic #{index}", "status" => "passed" }
          end
        end
        examples << { "id" => "./spec/corrupted_resilience_spec.rb[1:1]",
                      "file_path" => "./spec/corrupted_resilience_spec.rb",
                      "description" => Emfsvg::ReleasedQualification::CORRUPT_EXAMPLE, "status" => "passed" }
        (@manifest.fetch("baseline").fetch("whole_suite_examples") - examples.size).times do |index|
          examples << { "id" => "./spec/other_spec.rb[1:#{index}]", "file_path" => "./spec/other_spec.rb",
                        "description" => "synthetic extra #{index}", "status" => "passed" }
        end
        { "examples" => examples, "summary" => { "example_count" => examples.size, "failure_count" => 0,
                                                 "pending_count" => 0, "errors_outside_of_examples_count" => 0 } }
      end

      def write_release_report(document)
        File.write(@report_path, JSON.generate(document))
      end

      def build_release_archive(source_revision = @manifest.dig("provenance", "runtime", "source_revision"))
        spec = Gem::Specification.new do |gem|
          gem.name = "emf"
          gem.version = "9.8.7"
          gem.summary = "Synthetic qualification fixture"
          gem.authors = ["Fixture"]
          gem.files = []
          gem.metadata = source_revision ? { "source_revision" => source_revision } : {}
        end
        path = File.join(@directory, "emf.gem")
        Gem::Package.build(spec, true, false, path)
        @manifest.fetch("provenance").fetch("runtime")["package_sha256"] = Digest::SHA256.file(path).hexdigest
        write_release_manifest(@manifest)
        path
      end
    end
  end
end
