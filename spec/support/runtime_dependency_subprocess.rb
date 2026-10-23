# frozen_string_literal: true

if $PROGRAM_NAME == __FILE__
  require "bundler/setup"
  require "emf"
  require "json"
  require "open3"

  lockfile, expected_revision, expected_remote = ARGV
  locked = Bundler::LockfileParser.new(Bundler.read_file(lockfile)).specs.find { |spec| spec.name == "emf" }
  source = locked&.source
  unless source.is_a?(Bundler::Source::Git) && source.uri == expected_remote &&
         source.revision == expected_revision && source.ref == expected_revision
    abort "emf lock source must be #{expected_remote} at full ref/revision #{expected_revision}"
  end

  loaded = Gem.loaded_specs.fetch("emf")
  loaded_source = loaded.source
  unless loaded_source.is_a?(Bundler::Source::Git) && loaded_source.uri == expected_remote
    abort "loaded emf is not from #{expected_remote}"
  end
  actual, error, status = Open3.capture3("git", "-C", loaded.full_gem_path, "rev-parse", "HEAD")
  unless status.success? && actual.strip == expected_revision
    abort "loaded emf revision #{actual.strip.inspect} differs from #{expected_revision}: #{error.strip}"
  end
  feature = $LOADED_FEATURES.find { |path| path.end_with?("/emf.rb") }
  unless feature && File.realpath(feature) == File.realpath(File.join(loaded.full_gem_path, "lib/emf.rb"))
    abort "emf entry point was not loaded from the pinned checkout: " \
          "expected #{File.join(loaded.full_gem_path, 'lib/emf.rb').inspect}, " \
          "candidates #{$LOADED_FEATURES.grep(/emf\.rb\z/).inspect}"
  end
  puts JSON.generate("revision" => actual.strip, "remote" => loaded_source.uri,
                     "gem_path" => loaded.full_gem_path, "entry_point" => feature)
end
