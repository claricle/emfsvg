# frozen_string_literal: true

require "rbconfig"

module Emfsvg
  module SpecSupport
    module ParityToolingFixture
      include ParityInventoryFixture

      def with_parity_tooling
        with_parity_inventory do |root, project, manifest_path, data|
          install_parity_tooling(project, manifest_path)
          marker = File.join(project, "conversions.log")
          probe = File.join(project, "conversion_probe.rb")
          File.write(probe, conversion_probe)
          reference = File.join(project, "reference")
          File.write(reference, <<~SH)
            #!/bin/sh
            printf 'reference\\n' >> "$TOOLING_CONVERSIONS"
            printf '<svg/>' > "$2"
          SH
          File.chmod(0o755, reference)
          environment = { "EMF_FIXTURE_ROOT" => root, "EMF2SVG_REF_PATH" => reference,
                          "EMF2SVG_REF_LIB_DIR" => project, "TOOLING_CONVERSIONS" => marker }
          yield root, project, data, environment, probe, marker
        end
      end

      def install_parity_tooling(project, manifest_path)
        FileUtils.mkdir_p(File.join(project, "scripts"))
        FileUtils.mkdir_p(File.join(project, "spec/support"))
        %w[run_compat_check.rb run_round_trip.rb run_emf_svg_compare.rb].each do |script|
          FileUtils.cp(File.join(ParityCorpus::PROJECT_ROOT, "scripts", script), File.join(project, "scripts", script))
        end
        %w[parity_corpus.rb emfsvg_compat.rb svg_matcher.rb].each do |support|
          FileUtils.cp(File.join(__dir__, support), File.join(project, "spec/support", support))
        end
        FileUtils.cp(manifest_path, File.join(project, "spec/fixtures/parity_manifest.yml"))
      end

      def run_parity_tool(environment, project, probe, script, *arguments)
        Open3.capture3(environment, RbConfig.ruby, "-I", File.join(ParityCorpus::PROJECT_ROOT, "lib"),
                       "-r", probe, File.join(project, "scripts", script), *arguments)
      end

      def conversion_probe
        <<~RUBY
          require "emfsvg"
          module ToolingConversionProbe
            def from_file(...)
              File.open(ENV.fetch("TOOLING_CONVERSIONS"), "a") { |file| file.puts("from_file") }
              super
            end

            def from_svg(...)
              File.open(ENV.fetch("TOOLING_CONVERSIONS"), "a") { |file| file.puts("from_svg") }
              super
            end
          end
          Emfsvg.singleton_class.prepend(ToolingConversionProbe)
        RUBY
      end

      def materialize_tooling_conversions(root, project, data)
        svg = '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">' \
              '<rect x="1" y="1" width="2" height="2"/></svg>'
        emf = Emfsvg.from_svg(svg)
        data.fetch("fixtures").each do |entry|
          { "source" => [root, emf], "round_trip" => [project, svg] }.each do |kind, (base, bytes)|
            descriptor = entry.fetch(kind)
            File.binwrite(File.join(base, descriptor.fetch("path")), bytes)
            descriptor["sha256"] = Digest::SHA256.hexdigest(bytes)
          end
        end
        manifest_path = File.join(project, "spec/fixtures/parity_manifest.yml")
        File.write(manifest_path, YAML.dump(data))
        resolver = ParityCorpus.new(root: root, project_root: project, manifest_path: manifest_path)
        data.fetch("inventories")["round_trip_sha256"] = resolver.inventory_digest(["round_trip"])
        data.fetch("inventories")["aggregate_sha256"] = resolver.inventory_digest(%w[source golden round_trip])
        File.write(manifest_path, YAML.dump(data))
      end
    end
  end
end
