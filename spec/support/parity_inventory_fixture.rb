# frozen_string_literal: true

require "fileutils"
require "tmpdir"

module Emfsvg
  module SpecSupport
    module ParityInventoryFixture
      def with_parity_inventory
        Dir.mktmpdir("parity-inventory") do |directory|
          corpus_root = File.join(directory, "corpus")
          project_root = File.join(directory, "project")
          data = YAML.safe_load_file(ParityCorpus::MANIFEST_PATH)
          data.fetch("fixtures").each do |entry|
            ParityCorpus::ENTRY_KINDS.each do |kind|
              base = kind == "source" ? corpus_root : project_root
              write_inventory_file(base, entry.fetch(kind))
            end
          end
          data.fetch("corrupted").each { |entry| write_inventory_file(corpus_root, entry.fetch("source")) }
          run_inventory_git(corpus_root, "init", "--quiet")
          run_inventory_git(corpus_root, "add", ".")
          run_inventory_git(corpus_root, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.test",
                            "commit", "--quiet", "-m", "Fixture")
          data.fetch("provenance").fetch("corpus")["revision"] =
            run_inventory_git(corpus_root, "rev-parse", "HEAD").strip
          manifest_path = File.join(directory, "manifest.yml")
          File.write(manifest_path, YAML.dump(data))
          resolver = ParityCorpus.new(root: corpus_root, project_root: project_root, manifest_path: manifest_path)
          data.fetch("inventories")["round_trip_sha256"] = resolver.inventory_digest(["round_trip"])
          data.fetch("inventories")["aggregate_sha256"] = resolver.inventory_digest(%w[source golden round_trip])
          File.write(manifest_path, YAML.dump(data))
          yield corpus_root, project_root, manifest_path, data
        end
      end

      def write_inventory_file(base, descriptor)
        path = File.join(base, descriptor.fetch("path"))
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, "inventory fixture: #{descriptor.fetch('path')}\n")
        descriptor["sha256"] = Digest::SHA256.file(path).hexdigest
      end

      def run_inventory_git(root, *arguments)
        output, error, status = Open3.capture3("git", "-C", root, *arguments)
        raise error unless status.success?

        output
      end
    end
  end
end
