# frozen_string_literal: true

require "rubygems/package"
require "digest"
require "json"

module Emfsvg
  class RuntimePackageCheck
    class Error < StandardError; end

    ALLOWED_FILES = %r{\A(?:lib/(?:[a-zA-Z0-9_-]+/)*[a-zA-Z0-9_-]+\.(?:rb|txt)|exe/emfsvg|README\.adoc|LICENSE\.txt)\z}
    FORBIDDEN_REFERENCE = %r{(?:libemf2svg|emf2svg|(?:\A|[/_.-])compat(?:[/_.-]|\z))}i

    def initialize(path)
      @path = path
    end

    def call
      package = Gem::Package.new(@path)
      package.verify
      specification = package.spec
      raise Error, "Expected an emfsvg package, got #{specification.name}" unless specification.name == "emfsvg"

      files = package.contents.sort
      verify_files!(files, specification)
      dependencies = runtime_graph(specification)
      {
        "package" => File.basename(@path),
        "sha256" => Digest::SHA256.file(@path).hexdigest,
        "files" => files,
        "runtime_dependencies" => dependencies
      }
    rescue Gem::Package::Error, Gem::Exception, Gem::LoadError, SystemCallError => e
      raise Error, "Cannot verify package: #{e.message}"
    end

    private

    def verify_files!(files, specification)
      unexpected = files.reject { |file| ALLOWED_FILES.match?(file) && !FORBIDDEN_REFERENCE.match?(file) }
      raise Error, "Unexpected packaged files: #{unexpected.join(', ')}" unless unexpected.empty?
      raise Error, "Duplicate packaged paths" unless files.uniq == files

      expected = specification.files.sort
      raise Error, "Archive contents differ from gem metadata" unless expected == files

      required = %w[lib/emfsvg.rb lib/emfsvg/error.rb lib/emfsvg/version.rb exe/emfsvg README.adoc LICENSE.txt]
      missing = required - files
      raise Error, "Missing runtime files: #{missing.join(', ')}" unless missing.empty?
    end

    def runtime_graph(specification)
      graph = {}
      pending = specification.runtime_dependencies.dup
      until pending.empty?
        dependency = pending.shift
        if FORBIDDEN_REFERENCE.match?(dependency.name)
          raise Error, "Forbidden runtime reference dependency: #{dependency.name}"
        end

        installed = Gem.loaded_specs[dependency.name] || Gem::Specification.find_by_name(dependency.name,
                                                                                         dependency.requirement)
        unless dependency.requirement.satisfied_by?(installed.version)
          raise Error, "Loaded #{dependency.name} #{installed.version} does not satisfy #{dependency.requirement}"
        end
        next if graph.key?(installed.name)

        graph[installed.name] = installed.version.to_s
        pending.concat(installed.runtime_dependencies)
      end
      graph.sort.to_h
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    unless ARGV.size == 1
      raise Emfsvg::RuntimePackageCheck::Error,
            "Usage: ruby scripts/check_runtime_package.rb PATH.gem"
    end

    puts JSON.pretty_generate(Emfsvg::RuntimePackageCheck.new(ARGV.fetch(0)).call)
  rescue Emfsvg::RuntimePackageCheck::Error => e
    warn "Runtime package check failed: #{e.message}"
    exit 1
  end
end
