# frozen_string_literal: true

# Generate and verify both complete baselines in staging before promotion.
# Usage: bundle exec ruby scripts/regenerate_golden.rb (--check | --write)
# Requires EMF_FIXTURE_ROOT, EMF2SVG_REF_PATH and EMF2SVG_REF_LIB_DIR.
# See spec/fixtures/README.adoc for reference and corpus setup.

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../spec", __dir__))
require "emfsvg"
require "support/emfsvg_compat"
require "support/parity_corpus"
require "support/golden_regeneration"

begin
  unless [["--write"], ["--check"]].include?(ARGV)
    raise ArgumentError, "Usage: ruby scripts/regenerate_golden.rb (--check | --write)"
  end

  Emfsvg::Compat.validate_reference!
  regeneration = Emfsvg::SpecSupport::GoldenRegeneration.new(
    corpus: Emfsvg::SpecSupport::ParityCorpus.new,
    project_root: Emfsvg::SpecSupport::ParityCorpus::PROJECT_ROOT,
    manifest_path: Emfsvg::SpecSupport::ParityCorpus::MANIFEST_PATH,
    reference: Emfsvg::Compat.method(:generate_reference),
    svg_to_emf: Emfsvg.method(:from_svg), renderer: Emfsvg.method(:from_bytes)
  )
  exit(regeneration.run(check: ARGV.include?("--check")) ? 0 : 1)
rescue Emfsvg::Compat::SetupError, Emfsvg::SpecSupport::ParityCorpus::SetupError,
       Emfsvg::SpecSupport::GoldenRegeneration::Error, ArgumentError, SystemCallError => e
  warn "Golden regeneration failed: #{e.message}"
  exit 1
end
