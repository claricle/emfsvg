# frozen_string_literal: true

require "fileutils"
require "json"

module InstalledSourceContractFixture
  REVISION = "e0491ed331dff6c5996dcbd9a269b79ffebbcc38"

  def installed_source_fixture(directory, revision: REVISION, metadata_revision: nil)
    home = File.join(directory, "gem-home")
    root = File.join(home, "gems", "emf-0.1.3.pre.source")
    FileUtils.mkdir_p(File.join(root, "lib/emf/native"))
    FileUtils.mkdir_p(File.join(home, "specifications"))
    File.write(File.join(root, "lib/emf/native/provenance.json"), JSON.generate("revision" => revision))
    File.write(File.join(home, "specifications", "emf-0.1.3.pre.source.gemspec"), <<~GEMSPEC)
      Gem::Specification.new do |spec|
        spec.name = "emf"
        spec.version = "0.1.3.pre.source"
        spec.summary = "fixture"
        spec.authors = ["spec"]
        spec.files = []
        spec.metadata = { "source_revision" => #{metadata_revision.inspect} } if #{!metadata_revision.nil?}
      end
    GEMSPEC
    [home, root]
  end
end
