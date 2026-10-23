# frozen_string_literal: true

# Walks every EMF fixture, generates both libemf2svg reference output
# and emfsvg's output, and reports a compatibility matrix.
#
# Usage:
#   bundle exec ruby scripts/run_compat_check.rb [fixtures_glob]
#
# An optional glob filters the verified pinned source inventory.
# Requires explicit EMF_FIXTURE_ROOT, EMF2SVG_REF_PATH and EMF2SVG_REF_LIB_DIR.
# See spec/fixtures/README.adoc for setup.

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../spec", __dir__))
require "emfsvg"
require "support/emfsvg_compat"
require "support/parity_corpus"

begin
  Emfsvg::Compat.validate_reference!
  fixtures = Emfsvg::SpecSupport::ParityCorpus.new.source_paths
  if ARGV[0]
    pattern = File.expand_path(ARGV[0])
    fixtures = fixtures.select { |path| File.fnmatch?(pattern, path, File::FNM_PATHNAME | File::FNM_EXTGLOB) }
  end
  abort "No pinned fixtures match #{ARGV[0].inspect}; check the filter and EMF_FIXTURE_ROOT" if fixtures.empty?
rescue Emfsvg::Compat::SetupError, Emfsvg::SpecSupport::ParityCorpus::SetupError => e
  abort e.message
end

results = fixtures.map do |path|
  ref_svg = Emfsvg::Compat.generate_reference(path)
  emfsvg_svg = Emfsvg::Compat.generate_emfsvg(path)
  Emfsvg::Compat::Result.new(
    fixture: File.basename(path), ref_bytes: ref_svg.bytesize, emfsvg_bytes: emfsvg_svg.bytesize,
    ref_elements: Emfsvg::Compat.count_elements(Emfsvg::Compat.parse_svg(ref_svg)),
    emfsvg_elements: Emfsvg::Compat.count_elements(Emfsvg::Compat.parse_svg(emfsvg_svg))
  )
rescue Emfsvg::Compat::ConversionError => e
  abort e.message
end

puts "Compatibility matrix (#{results.size} fixtures)"
puts "=" * 80
puts "Fixture                                    ref(B)  out(B)    ratio  element_overlap"
puts "-" * 80
results.each { |r| puts r }
puts "=" * 80
puts Emfsvg::Compat.summarize(results)
