# frozen_string_literal: true

require "bundler"
require "digest"
require "fiddle"
require "json"

module Emfsvg
  module ResourceCalibration
    class QualificationProbe
      def self.call(lockfile, native_library)
        require "bundler/setup"
        require "emf"
        locked = Bundler::LockfileParser.new(Bundler.read_file(lockfile)).specs.select { |spec| spec.name == "emf" }
        loaded = Gem.loaded_specs.fetch("emf")
        released = locked.one? && locked.first.source.is_a?(Bundler::Source::Rubygems) &&
                   loaded.source.is_a?(Bundler::Source::Rubygems) && locked.first.version == loaded.version
        raise "locked and loaded emf must be the same released Rubygems version" unless released

        entrypoint = File.realpath($LOADED_FEATURES.find { |path| path.end_with?("/emf.rb") })
        root = File.realpath(loaded.full_gem_path)
        raise "shadowed emf entrypoint" unless entrypoint == File.join(root, "lib/emf.rb")

        library = Fiddle.dlopen(native_library)
        abi = Fiddle::Function.new(library["emf_abi_version"], [], Fiddle::TYPE_INT).call
        { "version" => loaded.version.to_s, "root" => root, "entrypoint" => entrypoint,
          "sha256" => Digest::SHA256.file(entrypoint).hexdigest, "abi" => abi.to_s }
      end
    end
  end
end

puts JSON.generate(Emfsvg::ResourceCalibration::QualificationProbe.call(*ARGV)) if $PROGRAM_NAME == __FILE__
