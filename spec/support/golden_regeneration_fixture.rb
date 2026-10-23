# frozen_string_literal: true

require "stringio"
require "json"
require "open3"
require "rbconfig"
require_relative "parity_inventory_fixture"

module Emfsvg
  module SpecSupport
    module GoldenRegenerationFixture
      include ParityInventoryFixture

      def with_regeneration(fail_name: nil, changed: false)
        with_parity_inventory do |root, project, manifest_path, data|
          binary = File.join(File.dirname(project), "reference")
          File.write(binary, JSON.generate(fail_name: fail_name, changed: changed))
          data.fetch("provenance")["c_reference"].merge!(
            "status" => "verified", "source_revision" => "a" * 40,
            "binary_sha256" => Digest::SHA256.file(binary).hexdigest
          )
          File.write(manifest_path, YAML.dump(data))
          previous = ENV.to_h.slice("EMF2SVG_REF_PATH", "EMF2SVG_REF_LIB_DIR")
          ENV["EMF2SVG_REF_PATH"] = binary
          ENV["EMF2SVG_REF_LIB_DIR"] = File.dirname(binary)
          FileUtils.touch(File.join(project, "spec/fixtures/.golden-regeneration.lock"))
          corpus = ParityCorpus.new(root: root, project_root: project, manifest_path: manifest_path)
          output = StringIO.new
          runner = regeneration_runner(root, project, manifest_path, output, corpus: corpus)
          yield runner, project, manifest_path, output, corpus
        ensure
          %w[EMF2SVG_REF_PATH EMF2SVG_REF_LIB_DIR].each do |key|
            previous&.key?(key) ? ENV[key] = previous.fetch(key) : ENV.delete(key)
          end
        end
      end

      def regeneration_runner(root, project, manifest_path, output, corpus: nil)
        corpus ||= ParityCorpus.new(root: root, project_root: project, manifest_path: manifest_path)
        configuration = JSON.parse(File.read(ENV.fetch("EMF2SVG_REF_PATH")))
        reference = lambda do |source|
          name = File.basename(source, ".emf")
          raise GoldenRegeneration::Error, "synthetic conversion failed" if name == configuration.fetch("fail_name")

          "inventory fixture: spec/fixtures/golden/#{name}.svg\n#{'changed' if configuration.fetch('changed')}"
        end
        renderer = lambda do |source|
          "inventory fixture: spec/fixtures/emfsvg_golden/#{File.basename(source, '.emf')}.svg\n"
        end
        GoldenRegeneration.new(corpus: corpus, project_root: project, manifest_path: manifest_path,
                               reference: reference, renderer: renderer, output: output)
      end

      def regeneration_process(*arguments)
        [RbConfig.ruby, File.join(__dir__, "golden_regeneration_subprocess.rb"), *arguments]
      end

      def regeneration_check_exit(corpus, project, manifest, output)
        bytes, error, status = Open3.capture3(*regeneration_process("check", corpus.root, project, manifest))
        raise GoldenRegeneration::Error, error unless [0, 1].include?(status.exitstatus)

        output.write(bytes)
        status.exitstatus
      end

      def regeneration_snapshot(project, manifest)
        files = Dir.glob(File.join(project, "**/*"), File::FNM_DOTMATCH).select { |path| File.file?(path) }
        (files + [manifest]).to_h do |path|
          [path, [File.binread(path), File.stat(path).mtime, File.stat(path).ino]]
        end
      end
    end
  end
end
