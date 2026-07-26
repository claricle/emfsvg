# frozen_string_literal: true

require "spec_helper"

# Round-trip integration spec. Two flavours:
#
# 1. Synthetic minimal SVGs — hand-crafted to exercise exactly the
#    features each phase implements. Must round-trip byte-equal.
# 2. emfsvg_golden/*.svg — the 208-fixture full golden set. Most
#    fixtures will diverge because they exercise features outside
#    v1 scope (glyph-index text, EMF+ records, pattern brushes).
#    Documented in spec/fixtures/svg_to_emf_known_divergent.txt.
RSpec.describe "SVG → EMF → SVG round-trip" do
  def roundtrip(svg_string)
    emf_bytes = Emfsvg.from_svg(svg_string)
    Emfsvg.from_bytes(emf_bytes)
  end

  def shape_only_svg(inner)
    <<~SVG
      <?xml version="1.0"  encoding="UTF-8" standalone="no"?>
      <svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="200.0000" height="200.0000">
      <g transform="translate(-0.0000, -0.0000)">
      #{inner}</g>
      </svg>
    SVG
  end

  describe "synthetic minimal SVGs" do
    def doc(inner, width: 200.0, height: 200.0, tx_val: "-0.0000", ty_val: "-0.0000")
      format(
        "<?xml version=\"1.0\"  encoding=\"UTF-8\" standalone=\"no\"?>\n" \
        "<svg version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\" " \
        "xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"%.4f\" height=\"%.4f\">\n" \
        "<g transform=\"translate(%s, %s)\">\n" \
        "%s" \
        "</g>\n</svg>\n",
        width, height, tx_val, ty_val, inner
      )
    end

    it "round-trips an empty SVG" do
      svg = doc("")
      expect(roundtrip(svg)).to eq(svg)
    end

    it "round-trips a single solid rect with default pen" do
      inner = "<rect x=\"10.0000\" y=\"20.0000\" width=\"100.0000\" height=\"50.0000\"  fill=\"#FFFFFF\" stroke=\"#000000\" stroke-width=\"1.0000\"  stroke-linecap=\"round\"  stroke-linejoin=\"round\" />\n"
      expect(roundtrip(doc(inner))).to eq(doc(inner))
    end

    it "round-trips an ellipse" do
      inner = "<ellipse cx=\"50.0000\" cy=\"40.0000\" rx=\"20.0000\" ry=\"10.0000\"  fill=\"#FF0000\" stroke=\"#000000\" stroke-width=\"1.0000\"  stroke-linecap=\"round\"  stroke-linejoin=\"round\" />\n"
      expect(roundtrip(doc(inner))).to eq(doc(inner))
    end

    it "round-trips a polyline (open path)" do
      inner = "<path d=\"M 0.0000,0.0000 L 100.0000,0.0000 L 100.0000,50.0000 \" stroke=\"#000000\" stroke-width=\"1.0000\"  stroke-linecap=\"round\"  stroke-linejoin=\"round\" fill=\"none\" />\n"
      expect(roundtrip(doc(inner))).to eq(doc(inner))
    end

    it "round-trips a closed polygon" do
      inner = "<path d=\"M 0.0000,0.0000 L 100.0000,0.0000 L 100.0000,50.0000 Z\" stroke=\"#000000\" stroke-width=\"1.0000\"  stroke-linecap=\"round\"  stroke-linejoin=\"round\"  fill=\"#FF0000\" />\n"
      expect(roundtrip(doc(inner))).to eq(doc(inner))
    end

    it "round-trips a nested group with identity translate" do
      inner = "<g transform=\"matrix(1.0000 0.0000 0.0000 1.0000 0.0000 0.0000)\">\n<rect x=\"0.0000\" y=\"0.0000\" width=\"10.0000\" height=\"10.0000\"  fill=\"#000000\" stroke=\"#000000\" stroke-width=\"1.0000\"  stroke-linecap=\"round\"  stroke-linejoin=\"round\" />\n</g>\n"
      expect(roundtrip(doc(inner))).to eq(doc(inner))
    end
  end

  describe "emfsvg_golden fixtures (regression floor)" do
    GOLDEN_DIR = Emfsvg::SpecSupport::FixturePath.fixture("emfsvg_golden")

    # Sample 5 fixtures to keep spec runtime reasonable. Full
    # comparison lives in scripts/run_round_trip.rb (developer tooling).
    let(:sample) { Dir.glob(File.join(GOLDEN_DIR, "*.svg")).first(5) }

    it "processes sampled fixtures without crashing" do
      sample.each do |path|
        svg = File.read(path)
        emf = Emfsvg.from_svg(svg)
        result = Emfsvg.from_bytes(emf)
        expect(result).to start_with("<?xml")
        expect(result).to include("<svg")
        expect(result).to include("</svg>")
      rescue StandardError => e
        raise "Fixture #{File.basename(path)} failed round-trip: #{e.class}: #{e.message[0, 100]}"
      end
    end
  end
end
