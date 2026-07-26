# frozen_string_literal: true

require "set"

# Walks every fixture in spec/fixtures/emfsvg_golden/, runs the
# SVG → EMF → SVG round-trip, and reports byte-equality AND lossy
# (semantic) equality. The lossy matcher tolerates:
#   * float rounding differences up to <tolerance> pixels (default 0.5)
#   * auto-generated clip/img IDs (BsdRand-driven)
#   * <defs> child ordering
#   * whitespace
#
# Usage:
#   bundle exec ruby scripts/run_round_trip.rb [limit] [tolerance]

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../spec", __dir__))
require "emfsvg"
require "support/svg_matcher"

GOLDEN_DIR = File.expand_path("../spec/fixtures/emfsvg_golden", __dir__)

def round_trip(svg_path)
  svg = File.read(svg_path)
  emf = Emfsvg.from_svg(svg)
  Emfsvg.from_bytes(emf)
rescue StandardError => e
  "ERROR: #{e.class}: #{e.message[0, 100]}"
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

limit = ARGV.first&.to_i
tolerance = (ARGV[1] || 0.5).to_f
all = Dir.glob(File.join(GOLDEN_DIR, "*.svg"))
fixtures = limit ? all.first(limit) : all

byte_equal = 0
lossy_equal = 0
errors = 0
fail_categories = Hash.new(0)

fixtures.each do |path|
  svg = File.read(path)
  result = round_trip(path)

  if result.is_a?(String) && result.start_with?("ERROR")
    errors += 1
    fail_categories["ERROR: #{result.split(':').first(2).join(':')}"] += 1
    next
  end

  if result == svg
    byte_equal += 1
    lossy_equal += 1
    next
  end

  comparison = Emfsvg::SvgMatcher.compare(svg, result, tolerance: tolerance)
  if comparison.equal
    lossy_equal += 1
    fail_categories["lossy-pass (byte-diff)"] += 1
  else
    category = categorise(comparison.reason || "")
    fail_categories[category] += 1
  end
end

puts "Round-trip results (tolerance=#{tolerance})"
puts "=" * 70
puts "Byte-equal:                #{byte_equal} / #{fixtures.size}"
puts "Lossy-equal (or stricter): #{lossy_equal} / #{fixtures.size}"
puts "Errors:                    #{errors}"
puts "Total processed:           #{fixtures.size}"
puts "Total in golden set:       #{all.size}"
puts "=" * 70
puts "Failure categories:"
fail_categories.sort_by { |_, c| -c }.each { |cat, count| puts "  #{cat.ljust(40)} #{count}" }
