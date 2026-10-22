# frozen_string_literal: true

require "yaml"

# Checks recorded metadata only. Loaded runtime, native selection, and artifact
# verification require the upstream contracts and a separate qualification gate.
class ParityProvenance
  DEFAULT_MANIFEST = File.expand_path("../spec/fixtures/parity_manifest.yml", __dir__)
  REVISION = /\A[0-9a-f]{40}\z/
  SHA256 = /\A[0-9a-f]{64}\z/
  ISSUE = %r{\Ahttps://github\.com/claricle/emf/issues/[1-9][0-9]*\z}

  def initialize(path = DEFAULT_MANIFEST)
    @manifest = YAML.safe_load_file(path)
  end

  def errors
    problems = []
    requirements.each do |path, expected|
      value = lookup(path)
      valid = expected.is_a?(Regexp) ? value.is_a?(String) && expected.match?(value) : value == expected
      problems << "#{path}: expected #{expected.inspect}, got #{value.inspect}" unless valid
    end
    problems
  end

  def self.run(path = DEFAULT_MANIFEST, output: $stdout, error_output: $stderr)
    problems = new(path).errors
    if problems.empty?
      output.puts "Parity provenance metadata is ready; runtime and native qualification remain separate checks."
      return 0
    end

    error_output.puts "Parity provenance metadata is not ready:"
    problems.each { |problem| error_output.puts "- #{problem}" }
    1
  rescue Psych::Exception, SystemCallError => e
    error_output.puts "Parity provenance metadata could not be read: #{e.message}"
    1
  end

  private

  def lookup(path)
    path.split(".").reduce(@manifest) do |value, key|
      break :missing unless value.is_a?(Hash) && value.key?(key)

      value[key]
    end
  end

  def requirements
    {
      "schema_version" => 1,
      "baseline.revision" => REVISION,
      "provenance.corpus.repository" => "https://github.com/claricle/emf.git",
      "provenance.corpus.revision" => REVISION,
      "provenance.runtime.status" => "qualified",
      "provenance.runtime.source" => "rubygems",
      "provenance.runtime.version" => /\A\d+\.\d+\.\d+\z/,
      "provenance.runtime.source_revision" => REVISION,
      "provenance.runtime.package_sha256" => SHA256,
      **contract_requirements,
      "provenance.native_library.status" => "qualified",
      "provenance.native_library.source_revision" => REVISION,
      "provenance.native_library.artifact_sha256" => SHA256,
      "provenance.native_library.abi" => /\A\S.*\z/,
      "provenance.production_backend.requested" => "auto",
      "provenance.production_backend.required_selected" => "native",
      "provenance.c_reference.status" => "verified",
      "provenance.c_reference.reported_version" => /\A\S.*\z/,
      "provenance.c_reference.source_revision" => REVISION,
      "provenance.c_reference.build_recipe" => /\A\S.*\z/,
      "provenance.c_reference.generation_command" => /\A\S.*\z/,
      "provenance.c_reference.wrapper_options.nameSpace" => nil,
      "provenance.c_reference.wrapper_options.verbose" => 0,
      "provenance.c_reference.wrapper_options.emfplus" => 1,
      "provenance.c_reference.wrapper_options.svgDelimiter" => 1,
      "provenance.c_reference.wrapper_options.imgWidth" => 0,
      "provenance.c_reference.wrapper_options.imgHeight" => 0
    }
  end

  def contract_requirements
    %w[model diagnostics resources].each_with_object({}) do |contract, fields|
      fields["provenance.upstream_contracts.#{contract}.issue"] = ISSUE
      fields["provenance.upstream_contracts.#{contract}.landed_revision"] = REVISION
    end
  end
end

exit ParityProvenance.run(ARGV.fetch(0, ParityProvenance::DEFAULT_MANIFEST)) if $PROGRAM_NAME == __FILE__
