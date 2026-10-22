# frozen_string_literal: true

# EMF→SVG fidelity comparison: for every EMF fixture, runs both emfsvg
# (Ruby) and libemf2svg (C reference), then compares their outputs
# with the lossy SvgMatcher. Reports semantic-equivalence gaps
# categorised by failure mode (text, geometry, path d, structural).
#
# Usage:
#   bundle exec ruby scripts/run_emf_svg_compare.rb [limit]
#
# Requires libemf2svg's `emf2svg_ref` binary at:
#   /Users/mulgogi/src/claricle/libemf2svg/emf2svg_ref
# (or set EMF2SVG_REF_PATH env var).

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../spec", __dir__))
require "emfsvg"
require "support/svg_matcher"
require "open3"
require "tmpdir"

REF_BINARY_DEFAULT = "/Users/mulgogi/src/claricle/libemf2svg/emf2svg_ref"
REF_LIB_DIR_DEFAULT = "/Users/mulgogi/src/claricle/libemf2svg/build"
EMF_GLOBS = %w[
  ../emf/spec/fixtures/emf/*.emf
  ../emf/spec/fixtures/emf-ea/*.emf
  ../emf/spec/fixtures/simple/*.emf
].freeze

def ref_binary_path
  ENV.fetch("EMF2SVG_REF_PATH", REF_BINARY_DEFAULT)
end

def ref_lib_dir
  ENV.fetch("EMF2SVG_REF_LIB_DIR", REF_LIB_DIR_DEFAULT)
end

def ref_available?
  File.executable?(ref_binary_path)
end

def generate_reference(emf_path)
  output_path = File.join(Dir.mktmpdir, "#{File.basename(emf_path, '.emf')}.svg")
  env = { "DYLD_LIBRARY_PATH" => ref_lib_dir }
  _, _, status = Open3.capture3(env, ref_binary_path, emf_path, output_path)
  return nil unless status.success?

  File.binread(output_path)
ensure
  File.delete(output_path) if output_path && File.exist?(output_path)
end

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

base_dir = File.expand_path(File.join(__dir__, ".."))
all_emfs = EMF_GLOBS.flat_map do |g|
  Dir.glob(File.expand_path(g, base_dir))
end.sort.uniq

limit = ARGV.first&.to_i
tolerance = (ARGV[1] || 1.0).to_f
fixtures = limit ? all_emfs.first(limit) : all_emfs

unless ref_available?
  warn "libemf2svg reference binary not found at #{ref_binary_path}."
  warn "Build it first: see spec/fixtures/README.adoc"
  exit 1
end

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
    next
  end
  emfsvg_ok += 1

  ref_svg = generate_reference(emf_path)
  unless ref_svg
    errors += 1
    fail_categories["ref-error"] += 1
    next
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
