# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::Svg::Paint do
  describe ".from_fill" do
    it "parses a solid color" do
      paint = described_class.from_fill("#FF0000")
      expect(paint.style).to eq(Emfsvg::Svg::Paint::SOLID)
      expect(paint.color.red).to eq(255)
    end

    it "treats 'none' as NULL style" do
      paint = described_class.from_fill("none")
      expect(paint.null?).to be true
      expect(paint.style).to eq(Emfsvg::Svg::Paint::NULL)
    end
  end

  describe ".from_stroke" do
    it "parses a solid stroke color" do
      paint = described_class.from_stroke("#00FF00")
      expect(paint.color.green).to eq(255)
    end
  end
end

RSpec.describe Emfsvg::Svg::Stroke do
  describe ".parse" do
    it "builds a Stroke from raw SVG attributes" do
      stroke = described_class.parse(
        stroke: "#0000FF", width: "2", dash_array: "5,3",
        line_cap: "round", line_join: "bevel"
      )
      expect(stroke.paint.color.blue).to eq(255)
      expect(stroke.width).to eq(2.0)
      expect(stroke.dash_array).to eq([5.0, 3.0])
      expect(stroke.line_cap).to eq("round")
      expect(stroke.line_join).to eq("bevel")
    end

    it "defaults width to 1.0 and cap/join to round/round (matching emfsvg pen defaults)" do
      stroke = described_class.parse(stroke: "black", width: nil, dash_array: nil,
                                     line_cap: nil, line_join: nil)
      expect(stroke.width).to eq(1.0)
      expect(stroke.line_cap).to eq("round")
      expect(stroke.line_join).to eq("round")
    end

    it "parses the miter limit and defaults it to the EMF device-context value" do
      explicit = described_class.parse(stroke: "black", width: nil, dash_array: nil,
                                       line_cap: nil, line_join: nil, miter_limit: "5")
      defaulted = described_class.parse(stroke: "black", width: nil, dash_array: nil,
                                        line_cap: nil, line_join: nil)

      expect(explicit.miter_limit).to eq(5.0)
      expect(defaulted.miter_limit).to eq(10.0)
    end

    it "treats null stroke as PS_NULL pen style" do
      stroke = described_class.parse(stroke: "none", width: nil, dash_array: nil,
                                     line_cap: nil, line_join: nil)
      expect(stroke.pen_style & 0xFF).to eq(5) # PS_NULL
    end

    it "packs endcap and join bits" do
      stroke = described_class.parse(stroke: "black", width: "1", dash_array: nil,
                                     line_cap: "square", line_join: "miter")
      expect(stroke.pen_style & 0x0F00).to eq(0x0100) # PS_ENDCAP_SQUARE
      expect(stroke.pen_style & 0xF000).to eq(0x2000) # PS_JOIN_MITER
    end

    it "heuristic-detects dot vs dash from dasharray" do
      short = described_class.parse(stroke: "black", width: "2", dash_array: "1,2",
                                    line_cap: nil, line_join: nil)
      expect(short.pen_style & 0xFF).to eq(2) # PS_DOT
      long = described_class.parse(stroke: "black", width: "1", dash_array: "5,5",
                                   line_cap: nil, line_join: nil)
      expect(long.pen_style & 0xFF).to eq(1) # PS_DASH
    end
  end
end
