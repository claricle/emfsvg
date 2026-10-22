# frozen_string_literal: true

# One-off investigation script: runs the SVG→EMF→SVG round-trip on
# every fixture, dumps per-fixture failure category + reason. Useful
# for identifying patterns across multiple fixtures.
#
# Usage: bundle exec ruby scripts/diagnose_round_trip.rb [limit]

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../spec", __dir__))
require "emfsvg"
require "support/svg_matcher"

GOLDEN_DIR = File.expand_path("../spec/fixtures/emfsvg_golden", __dir__)

all = Dir.glob(File.join(GOLDEN_DIR, "*.svg"))
fixtures = ARGV.first&.to_i ? all.first(ARGV.first.to_i) : all

fixtures.each do |path|
  name = File.basename(path)
  svg = File.read(path)

  emf = begin
    Emfsvg.from_svg(svg)
  rescue StandardError => e
    puts "#{name}: ERROR #{e.class}: #{e.message[0, 80]}"
    next
  end

  result = begin
    Emfsvg.from_bytes(emf)
  rescue StandardError => e
    puts "#{name}: RENDER-ERROR #{e.class}: #{e.message[0, 80]}"
    next
  end

  if result == svg
    puts "#{name}: BYTE-EQUAL"
    next
  end

  comparison = Emfsvg::SvgMatcher.compare(svg, result, tolerance: 1.0)
  if comparison.equal
    puts "#{name}: LOSSY-PASS"
  else
    puts "#{name}: FAIL #{comparison.reason[0, 120]}"
  end
end
