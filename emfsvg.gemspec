# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("lib", __dir__))
require "emfsvg/version"

Gem::Specification.new do |spec|
  spec.name = "emfsvg"
  spec.version = Emfsvg::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "EMF <-> SVG transformer (Ruby)."
  spec.description = "Convert Microsoft Enhanced Metafile (EMF) to SVG and back. " \
                     "Consumes the `emf` gem's domain model. Replaces the FFI " \
                     "wrapper around libemf2svg with a pure-Ruby transformer."
  spec.homepage = "https://github.com/claricle/emfsvg"
  spec.license = "BSD-2-Clause"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.adoc"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.glob("lib/**/*.rb") + %w[README.adoc LICENSE.txt]
  spec.bindir = "exe"
  spec.executables = %w[emfsvg]
  spec.require_paths = %w[lib]

  spec.add_dependency "emf", "~> 0.1"
end
