# frozen_string_literal: true

# EMF→SVG fidelity comparison: for every EMF fixture, runs both emfsvg
# (Ruby) and libemf2svg (C reference), then compares their outputs
# with the lossy SvgMatcher. Reports semantic-equivalence gaps
# categorised by failure mode (text, geometry, path d, structural).
#
# Usage:
#   bundle exec ruby scripts/run_emf_svg_compare.rb [limit] [tolerance]
#
# Requires explicit EMF_FIXTURE_ROOT, EMF2SVG_REF_PATH and EMF2SVG_REF_LIB_DIR.
# See spec/fixtures/README.adoc for the pinned corpus and reference setup.

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../spec", __dir__))
require "emfsvg"
require "support/svg_matcher"
require "support/emfsvg_compat"
require "support/parity_corpus"

def categorise(reason)
  case reason
  when /text content|text "/ then "text content"
  when /@d\b|"d"/ then "path d"
  when /@transform|"transform"/ then "transform attr"
  when /@clip-path|"clip-path"/ then "clip-path attr"
  when /<defs>/ then "defs multiset"
  when /child count/ then "child count mismatch"
  when /missing node/ then "missing element"
  when /\btag\b/ then "element tag"
  when /@fill\b|"fill"/ then "fill attr"
  when /@stroke\b|"stroke"/ then "stroke attr"
  when /@stroke-width|"stroke-width"/ then "stroke-width attr"
  when /@font|"font/ then "font attr"
  when /@x\b|@y\b|@cx|@cy|@rx|@ry|@width|@height|"x"|"y"|"width"|"height"/ then "geometry attr"
  else "other"
  end
end

begin
  limit = ARGV.first && Integer(ARGV.first, 10)
  raise ArgumentError, "limit must be positive" if limit && !limit.positive?

  tolerance = Float(ARGV[1] || 1.0)
  raise ArgumentError, "tolerance must be finite and nonnegative" unless tolerance.finite? && tolerance >= 0

  Emfsvg::Compat.validate_reference!
  all_emfs = Emfsvg::SpecSupport::ParityCorpus.new.source_paths
rescue Emfsvg::Compat::SetupError, Emfsvg::SpecSupport::ParityCorpus::SetupError, ArgumentError => e
  abort e.message
end
fixtures = limit ? all_emfs.first(limit) : all_emfs
abort "Pinned corpus contains no fixtures; check EMF_FIXTURE_ROOT" if fixtures.empty?

emfsvg_ok = 0
ref_ok = 0
lossy_pass = 0
byte_equal = 0
errors = 0
fail_categories = Hash.new(0)

fixtures.each do |emf_path|
  emfsvg_svg = begin
    Emfsvg.from_file(emf_path)
  rescue StandardError => e
    errors += 1
    fail_categories["emfsvg-error: #{e.class}"] += 1
    warn "#{emf_path}: #{e.class}: #{e.message}"
    next
  end
  emfsvg_ok += 1

  ref_svg = begin
    Emfsvg::Compat.generate_reference(emf_path)
  rescue Emfsvg::Compat::ConversionError => e
    abort e.message
  end
  ref_ok += 1

  if emfsvg_svg == ref_svg
    byte_equal += 1
    lossy_pass += 1
    next
  end

  comparison = Emfsvg::SvgMatcher.compare(emfsvg_svg, ref_svg, tolerance: tolerance)
  next lossy_pass += 1 if comparison.equal

  fail_categories[categorise(comparison.reason || "")] += 1
end

puts "EMF→SVG fidelity vs libemf2svg (tolerance=#{tolerance})"
puts "=" * 70
puts "Total fixtures:           #{fixtures.size}"
puts "emfsvg rendered:          #{emfsvg_ok}"
puts "libemf2svg rendered:      #{ref_ok}"
puts "Byte-equal:               #{byte_equal}"
puts "Lossy-equal:              #{lossy_pass}"
puts "Errors:                   #{errors}"
puts "Pass rate:                #{(lossy_pass.to_f / fixtures.size * 100).round(1)}%"
puts "=" * 70
puts "Failure categories:"
fail_categories.sort_by { |_, c| -c }.each { |cat, count| puts "  #{cat.ljust(40)} #{count}" }

exit 1 if errors.positive?
