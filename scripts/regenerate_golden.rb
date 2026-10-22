# frozen_string_literal: true

# Regenerates both golden fixture sets:
#   spec/fixtures/golden/<name>.svg        — libemf2svg reference output
#   spec/fixtures/emfsvg_golden/<name>.svg — emfsvg current output
#
# Usage:
#   bundle exec ruby scripts/regenerate_golden.rb
#
# Requires explicit EMF_FIXTURE_ROOT, EMF2SVG_REF_PATH, and EMF2SVG_REF_LIB_DIR.
# See spec/fixtures/README.adoc for setup instructions.

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../spec", __dir__))
require "emfsvg"
require "support/emfsvg_compat"
require "support/parity_corpus"
require "fileutils"

begin
  Emfsvg::Compat.validate_reference!
  source_paths = Emfsvg::SpecSupport::ParityCorpus.new.source_paths
rescue Emfsvg::Compat::SetupError, Emfsvg::SpecSupport::ParityCorpus::SetupError => e
  warn "Golden regeneration setup failed: #{e.message}"
  exit 1
end

REF_DIR = File.expand_path("../spec/fixtures/golden", __dir__)
EMFSVG_DIR = File.expand_path("../spec/fixtures/emfsvg_golden", __dir__)

FileUtils.mkdir_p(REF_DIR)
FileUtils.mkdir_p(EMFSVG_DIR)

ref_ok = ref_fail = emfsvg_ok = emfsvg_fail = 0

source_paths.each do |emf|
  name = File.basename(emf, ".emf")
  ref_path = File.join(REF_DIR, "#{name}.svg")
  emfsvg_path = File.join(EMFSVG_DIR, "#{name}.svg")

  # libemf2svg reference
  begin
    svg = Emfsvg::Compat.generate_reference(emf, ref_path)
    if svg
      File.binwrite(ref_path, svg)
      ref_ok += 1
    else
      warn "C reference produced no SVG for #{emf}"
      ref_fail += 1
    end
  rescue StandardError => e
    warn "C reference failed for #{emf}: #{e.message}"
    ref_fail += 1
  end

  # emfsvg current
  begin
    svg = Emfsvg.from_file(emf)
    File.write(emfsvg_path, svg)
    emfsvg_ok += 1
  rescue StandardError => e
    warn "emfsvg conversion failed for #{emf}: #{e.message}"
    emfsvg_fail += 1
  end
end

puts "libemf2svg golden: #{ref_ok} ok, #{ref_fail} failed"
puts "emfsvg golden:     #{emfsvg_ok} ok, #{emfsvg_fail} failed"
puts "Reference dir:    #{REF_DIR}"
puts "emfsvg dir:       #{EMFSVG_DIR}"

exit 1 if ref_fail.positive? || emfsvg_fail.positive?
