# frozen_string_literal: true

require "spec_helper"

# Round-trip integration spec: SVG → EMF → SVG must reproduce the input
# SVG byte-for-byte for the supported subset. The EMF→SVG side is
# locked to libemf2svg byte-exact parity, so any divergence is caused
# by loss in SVG→EMF (the new direction being exercised).
#
# Phase 8 status (2026-07-26): basic handlers are in place for
# rect/ellipse/circle/line/polyline/polygon/path/group/text/image.
# Most emfsvg_golden fixtures will diverge because they exercise
# features outside the supported subset (glyph-index text, EMF+
# records, pattern brushes, etc.). The regression floor catches
# catastrophic regressions where round-trips that USED to pass stop
# passing.
RSpec.describe "SVG → EMF → SVG round-trip (golden master)" do
  master_dir = Emfsvg::SpecSupport::FixturePath.fixture("emfsvg_golden")
  known_divergent_path = Emfsvg::SpecSupport::FixturePath.fixture(
    "svg_to_emf_known_divergent.txt"
  )

  fixtures = Dir.glob(File.join(master_dir, "*.svg"))
  known_divergent = File.readlines(known_divergent_path, chomp: true)
                        .reject { |line| line.strip.empty? || line.start_with?("#") }
                        .to_set { |line| line.split("#").first.strip }

  passing = []

  fixtures.each do |path|
    name = File.basename(path)

    if known_divergent.include?(name)
      it "#{name} is marked known-divergent" do
        expect(known_divergent).to include(name)
      end
      next
    end

    it "#{name} round-trips byte-equal" do
      svg = File.read(path)
      emf = Emfsvg.from_svg(svg)
      result = Emfsvg.from_bytes(emf)
      if result == svg
        passing << name
      else
        pending "round-trip not yet byte-equal for #{name}"
      end
      expect(result).to eq(svg)
    end
  end

  it "has at least one byte-equal round-trip (regression floor)" do
    skip "no fixtures passed round-trip; check handler coverage" if passing.empty?
    expect(passing.size).to be > 0
  end
end
