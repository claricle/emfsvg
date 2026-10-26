# frozen_string_literal: true

require "fileutils"
require "rubygems/package"
require_relative "../../scripts/support/calibration_qualification"

module Emfsvg
  module SpecSupport
    module CalibrationQualificationFixture
      SVG = '<svg xmlns="http://www.w3.org/2000/svg"/>'
      REVISION = "a" * 40

      def qualification_fixture(directory)
        @directory = File.realpath(directory)
        directory = @directory
        @runtime_root = File.join(directory, "installed")
        FileUtils.mkdir_p(File.join(@runtime_root, "lib"))
        File.write(File.join(@runtime_root, "lib/emf.rb"), "# controlled release fixture\n")
        @package_path = File.join(directory, "emf.gem")
        build_controlled_package
        @native_path = File.join(directory, "native.so")
        File.write(@native_path, "controlled native artifact; never loaded")
        @lockfile = File.join(directory, "Gemfile.lock")
        File.write(@lockfile, "controlled lock fixture; probe is supplied by test runner")
        build_qualification_manifest
        pin_qualification_inventory
        write_qualification_evidence
        @calls = []
        @mutate_report = nil
        @runner = ResourceCalibrationFixture::Runner.new
        allow(@runner).to receive(:run) do |**request|
          @calls << request
          value = controlled_qualification_report(request)
          @mutate_report&.call(value, request)
          { success: true, breach: nil, signal: nil, status: :exited, exitstatus: 0, stderr: "",
            stdout: JSON.generate(value),
            mechanism: { rss: "/proc/status", address_space: "child RLIMIT_AS", time: "monotonic parent watchdog" } }
        end
      end

      def build_controlled_package
        spec = Gem::Specification.new do |value|
          value.name = "emf"
          value.version = "1.2.3"
          value.summary = "controlled qualification fixture"
          value.authors = ["Fixture"]
          value.files = ["lib/emf.rb"]
          value.metadata["source_revision"] = REVISION
        end
        capture = StringIO.new
        previous = $stdout
        $stdout = capture
        Dir.chdir(@runtime_root) { Gem::Package.build(spec, true, false, @package_path) }
        $stdout = previous
      ensure
        $stdout = previous if previous
      end

      def build_qualification_manifest
        @manifest = YAML.safe_load_file(File.expand_path("../fixtures/parity_manifest.yml", __dir__))
        provenance = @manifest.fetch("provenance")
        provenance["runtime"] = { "status" => "qualified", "source" => "rubygems", "version" => "1.2.3",
                                  "source_revision" => REVISION, "package_sha256" => sha(@package_path) }
        provenance.fetch("upstream_contracts").each_value { |entry| entry["landed_revision"] = REVISION }
        provenance["native_library"] = { "status" => "qualified", "source_revision" => REVISION,
                                         "artifact_sha256" => sha(@native_path), "abi" => "1" }
        @manifest["fixtures"] = (0...9).map do |number|
          controlled_input("valid-#{number}").merge("round_trip" => {
                                                      "path" => "control-#{number}.svg", "sha256" => Digest::SHA256.hexdigest(SVG)
                                                    })
        end
        @manifest["fixed_sample"] = @manifest.fetch("fixtures").map { |entry| entry.fetch("name") }
        @manifest["corrupted"] = (0...21).map { |number| controlled_input("corrupt-#{number}") }
        @ledger = @manifest.fetch("corrupted").to_h do |entry|
          [entry.fetch("name"), { "source" => entry.fetch("source"), "reviewed" => true,
                                  "evidence" => [{ "kind" => "requirement",
                                                   "reference" => "controlled requirement #{entry.fetch('name')}" }],
                                  "expected_outcome" => { "kind" => "unreadable", "warnings" => [],
                                                          "exception" => controlled_exception(entry.fetch("name")) } }]
        end
      end

      def controlled_input(name)
        path = File.join(@directory, "#{name}.emf")
        File.write(path, "independent fixture input #{name}")
        { "name" => name, "source" => { "path" => File.basename(path), "sha256" => sha(path) },
          "expected_outcome" => nil }
      end

      def pin_qualification_inventory
        inventory = Emfsvg::ResourceCalibration::QualificationInventory
        valid = @manifest.fetch("fixtures").map { |entry| entry.slice("name", "source", "round_trip") }
        corrupt = @manifest.fetch("corrupted").map do |entry|
          entry.slice("name", "source")
        end
        corrupt.sort_by! { |entry| entry.fetch("name") }
        stub_const("#{inventory}::VALID_IDENTITY", Digest::SHA256.hexdigest(JSON.generate(valid)))
        stub_const("#{inventory}::CORRUPT_IDENTITY", Digest::SHA256.hexdigest(JSON.generate(corrupt)))
      end

      def write_qualification_evidence
        @manifest_path = File.join(@directory, "manifest.yml")
        File.write(@manifest_path, YAML.dump(JSON.parse(JSON.generate(@manifest))))
        File.write(File.join(@directory, "reviewed_corrupt_outcomes.json"), JSON.generate(@ledger))
        @native_provenance = File.join(@directory, "native.json")
        File.write(@native_provenance, JSON.generate(@manifest.dig("provenance", "native_library").except("status")))
      end

      def qualify
        Emfsvg::ResourceCalibration::Prerequisites.verify!(
          @manifest_path, @directory, package_path: @package_path, native_library: @native_path,
                                      native_provenance_path: @native_provenance, lockfile: @lockfile, runner: @runner
        )
      end

      def controlled_qualification_report(request)
        identity = { "root" => @runtime_root, "entrypoint" => File.join(@runtime_root, "lib/emf.rb"),
                     "sha256" => sha(File.join(@runtime_root, "lib/emf.rb")), "version" => "1.2.3", "abi" => "1" }
        return identity if request.fetch(:basename) == "runtime-identity"

        command = request.fetch(:command)
        backend = command[-4]
        input = JSON.parse(command.last)
        name = File.basename(input.fetch("path"), ".emf")
        selection = { "selected" => backend == "ruby" ? "ruby" : "native", "method" => "Emf.backend",
                      "public_contract" => true }
        valid = name.start_with?("valid")
        { "schema_version" => 1, "input_sha256" => input.fetch("sha256"),
          "input_bytes" => File.size(input.fetch("path")),
          "runtime" => identity.slice("entrypoint", "sha256", "version"), "backend" => backend,
          "native_sha256" => sha(@native_path), "selection_before" => selection, "selection_after" => selection,
          "svg" => valid ? SVG : nil, "output_bytes" => valid ? SVG.bytesize : 0, "warnings" => [],
          "exception" => valid ? nil : controlled_exception(name) }
      end

      def controlled_exception(name)
        { "class" => "Emfsvg::ParseError", "message" => "independent refusal #{name}",
          "cause" => { "class" => "Emf::FormatError", "message" => "independent refusal #{name}" } }
      end

      def sha(path)
        Digest::SHA256.file(path).hexdigest
      end
    end
  end
end
