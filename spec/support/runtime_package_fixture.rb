# frozen_string_literal: true

require "rubygems/package"
require "tmpdir"
require "fileutils"

module Emfsvg
  module SpecSupport
    module RuntimePackageFixture
      def with_runtime_package(extra_files: [], dependencies: [])
        Dir.mktmpdir("runtime-package") do |directory|
          files = %w[lib/emfsvg.rb lib/emfsvg/error.rb lib/emfsvg/version.rb exe/emfsvg README.adoc
                     LICENSE.txt] + extra_files
          files.each do |file|
            path = File.join(directory, file)
            FileUtils.mkdir_p(File.dirname(path))
            File.write(path, file == "exe/emfsvg" ? "#!/usr/bin/env ruby\n" : "fixture\n")
          end
          specification = Gem::Specification.new do |spec|
            spec.name = "emfsvg"
            spec.version = "0.0.1"
            spec.summary = "Package boundary fixture"
            spec.authors = ["Fixture"]
            spec.files = files
            dependencies.each { |name, requirement| spec.add_runtime_dependency(name, requirement) }
          end
          path = File.join(directory, "fixture.gem")
          Dir.chdir(directory) { Gem::Package.build(specification, true, false, path) }
          yield path
        end
      end
    end
  end
end
