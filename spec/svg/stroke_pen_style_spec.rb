# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::Svg::Stroke do
  describe "#pen_style with PS_GEOMETRIC" do
    it "includes PS_GEOMETRIC bit when width > 1" do
      stroke = described_class.parse(
        stroke: "#000000", width: "16", dash_array: nil,
        line_cap: "round", line_join: "round"
      )
      expect(stroke.pen_style & 0x000F0000).to eq(0x00010000)
    end

    it "includes PS_GEOMETRIC when an explicit unitless width is 1" do
      stroke = described_class.parse(
        stroke: "#000000", width: "1.0000", dash_array: nil,
        line_cap: "round", line_join: "round"
      )
      expect(stroke.pen_style & 0x000F0000).to eq(0x00010000)
    end

    it "keeps the default width cosmetic when no width was supplied" do
      stroke = described_class.parse(
        stroke: "#000000", width: nil, dash_array: nil,
        line_cap: "round", line_join: "round"
      )
      expect(stroke.pen_style & 0x000F0000).to eq(0)
    end

    it "keeps an explicit pixel width cosmetic" do
      stroke = described_class.parse(
        stroke: "#000000", width: "1px", dash_array: nil,
        line_cap: "round", line_join: "round"
      )
      expect(stroke.pen_style & 0x000F0000).to eq(0)
    end

    it "does NOT include PS_GEOMETRIC for NULL pen" do
      stroke = described_class.parse(
        stroke: "none", width: "16", dash_array: nil,
        line_cap: nil, line_join: nil
      )
      expect(stroke.pen_style & 0x000F0000).to eq(0)
    end

    it "preserves dash/endcap/join bits with GEOMETRIC" do
      stroke = described_class.parse(
        stroke: "#FF0000", width: "5", dash_array: nil,
        line_cap: "square", line_join: "miter"
      )
      expect(stroke.pen_style & 0x00010000).to eq(0x00010000) # GEOMETRIC
      expect(stroke.pen_style & 0x0F00).to eq(0x0100) # SQUARE cap
      expect(stroke.pen_style & 0xF000).to eq(0x2000) # MITER join
    end
  end

  describe "#null_pen_sentinel?" do
    it "is true when raw_width is '1px' and no explicit cap/join" do
      stroke = described_class.parse(
        stroke: "#000000", width: "1px", dash_array: nil,
        line_cap: nil, line_join: nil
      )
      expect(stroke.null_pen_sentinel?).to be true
    end

    it "is false when line_cap is explicit even with '1px'" do
      stroke = described_class.parse(
        stroke: "#000000", width: "1px", dash_array: nil,
        line_cap: "round", line_join: nil
      )
      expect(stroke.null_pen_sentinel?).to be false
    end

    it "is false when width is not '1px'" do
      stroke = described_class.parse(
        stroke: "#000000", width: "1.0000", dash_array: nil,
        line_cap: nil, line_join: nil
      )
      expect(stroke.null_pen_sentinel?).to be false
    end
  end
end
