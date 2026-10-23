# frozen_string_literal: true

require "open3"
require "rbconfig"
require "tmpdir"
require "json"

module Emfsvg
  module SpecSupport
    module RuntimeDependencyFixture
      RUNTIME_REVISION = "5c2c019138bab6f3c67f7602e8b410ba5a67c429"
      RUNTIME_REMOTE = "https://github.com/claricle/emf.git"
      LOCKFILE = File.expand_path("../../Gemfile.lock", __dir__)

      def runtime_dependency_observation(lockfile: LOCKFILE, revision: RUNTIME_REVISION, load_path: nil)
        ruby_options = load_path ? ["-I", load_path] : []
        Open3.capture3({ "EMF_FIXTURE_ROOT" => "/unavailable/emf-corpus" }, RbConfig.ruby,
                       *ruby_options, File.join(__dir__, "runtime_dependency_subprocess.rb"),
                       lockfile, revision, RUNTIME_REMOTE)
      end

      def with_runtime_dependency_lock(revision: RUNTIME_REVISION, remote: RUNTIME_REMOTE)
        Dir.mktmpdir("runtime-dependency") do |directory|
          lockfile = File.join(directory, "Gemfile.lock")
          contents = File.read(LOCKFILE).gsub(RUNTIME_REVISION, revision).gsub(RUNTIME_REMOTE, remote)
          File.write(lockfile, contents)
          yield lockfile
        end
      end
    end
  end
end
