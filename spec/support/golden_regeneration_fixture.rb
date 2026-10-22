# frozen_string_literal: true

require "stringio"
require_relative "parity_inventory_fixture"

module Emfsvg
  module SpecSupport
    module GoldenRegenerationFixture
      include ParityInventoryFixture

      def with_regeneration(fail_name: nil, changed: false)
        with_parity_inventory do |root, project, manifest_path, data|
          binary = File.join(File.dirname(project), "reference")
          File.write(binary, <<~SCRIPT)
            #!/bin/sh
            name="${1##*/}"
            name="${name%.emf}"
            if [ "$name" = "#{fail_name}" ]; then
              echo "synthetic conversion failed" >&2
              exit 1
            fi
            printf 'inventory fixture: spec/fixtures/golden/%s.svg\\n%s' "$name" "#{'changed' if changed}" > "$2"
          SCRIPT
          FileUtils.chmod(0o755, binary)
          data.fetch("provenance")["c_reference"].merge!(
            "status" => "verified", "source_revision" => "a" * 40,
            "binary_sha256" => Digest::SHA256.file(binary).hexdigest
          )
          File.write(manifest_path, YAML.dump(data))
          previous = ENV.to_h.slice("EMF2SVG_REF_PATH", "EMF2SVG_REF_LIB_DIR")
          ENV["EMF2SVG_REF_PATH"] = binary
          ENV["EMF2SVG_REF_LIB_DIR"] = File.dirname(binary)
          corpus = ParityCorpus.new(root: root, project_root: project, manifest_path: manifest_path)
          output = StringIO.new
          renderer = lambda do |source|
            "inventory fixture: spec/fixtures/emfsvg_golden/#{File.basename(source, '.emf')}.svg\n"
          end
          runner = GoldenRegeneration.new(corpus: corpus, project_root: project, manifest_path: manifest_path,
                                          reference: Compat.method(:generate_reference),
                                          renderer: renderer, output: output)
          yield runner, project, manifest_path, output, corpus
        ensure
          %w[EMF2SVG_REF_PATH EMF2SVG_REF_LIB_DIR].each do |key|
            previous&.key?(key) ? ENV[key] = previous.fetch(key) : ENV.delete(key)
          end
        end
      end

      def regeneration_check_exit(runner, output)
        reader, writer = IO.pipe
        pid = fork do
          reader.close
          success = runner.run(check: true)
          writer.write(output.string)
          writer.close
          exit!(success ? 0 : 1)
        end
        writer.close
        output.write(reader.read)
        reader.close
        Process.wait2(pid).last.exitstatus
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
