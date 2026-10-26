# frozen_string_literal: true

require "open3"
require "rbconfig"
require "tmpdir"
require "json"

module Emfsvg
  module SpecSupport
    module RuntimeDependencyFixture
      RUNTIME_REVISION = "327c36b49743bcb9799c20123218f0bae965f1de"
      RUNTIME_REMOTE = "https://github.com/claricle/emf.git"
      LOCKFILE = File.expand_path("../../Gemfile.lock", __dir__)

      def runtime_dependency_observation(lockfile: LOCKFILE, revision: RUNTIME_REVISION,
                                         remote: "https://rubygems.org", load_path: nil)
        ruby_options = load_path ? ["-I", load_path] : []
        Open3.capture3({ "EMF_FIXTURE_ROOT" => "/unavailable/emf-corpus" }, RbConfig.ruby,
                       *ruby_options, File.join(__dir__, "runtime_dependency_subprocess.rb"),
                       lockfile, revision, remote)
      end

      def with_runtime_dependency_lock(revision: RUNTIME_REVISION, remote: RUNTIME_REMOTE)
        Dir.mktmpdir("runtime-dependency") do |directory|
          lockfile = File.join(directory, "Gemfile.lock")
          contents = File.read(LOCKFILE).sub(/^    emf \(0\.2\.0\)\n/, "")
          git = "GIT\n  remote: #{remote}\n  revision: #{revision}\n  ref: #{revision}\n  specs:\n    emf (0.2.0)\n\n"
          contents = git + contents
          File.write(lockfile, contents)
          yield lockfile
        end
      end
    end
  end
end
