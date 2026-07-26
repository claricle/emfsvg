# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::Svg::Parser do
  describe ".call" do
    it "parses an empty SVG with width/height" do
      doc = described_class.call('<svg width="100" height="50"></svg>')
      expect(doc.width).to eq(100.0)
      expect(doc.height).to eq(50.0)
      expect(doc.view_box).to be_nil
    end

    it "parses viewBox into 4-tuple" do
      doc = described_class.call('<svg viewBox="0 0 200 100"></svg>')
      expect(doc.view_box).to eq([0.0, 0.0, 200.0, 100.0])
    end

    it "parses non-zero viewBox origin" do
      doc = described_class.call('<svg viewBox="10 20 200 100"></svg>')
      expect(doc.view_box).to eq([10.0, 20.0, 200.0, 100.0])
      expect(doc.bounds).to eq([10.0, 20.0, 200.0, 100.0])
    end

    it "strips CSS unit suffixes from dimensions" do
      doc = described_class.call('<svg width="100px" height="50px"></svg>')
      expect(doc.width).to eq(100.0)
      expect(doc.height).to eq(50.0)
    end

    it "raises ParseError on missing root element" do
      expect { described_class.call("not xml") }.to raise_error(Emfsvg::ParseError)
    end

    it "builds a child element list with registry-dispatched subclasses" do
      doc = described_class.call("<svg><g><rect/></g><circle/></svg>")
      children = doc.root_element.children
      expect(children.map(&:class)).to eq([Emfsvg::Svg::Elements::Group,
                                           Emfsvg::Svg::Elements::Circle])
    end
  end

  describe ".parse_dimension" do
    it "returns 0 for missing values" do
      expect(described_class.parse_dimension(nil)).to eq(0.0)
      expect(described_class.parse_dimension("")).to eq(0.0)
    end

    it "returns the float value" do
      expect(described_class.parse_dimension("42")).to eq(42.0)
      expect(described_class.parse_dimension("42.5")).to eq(42.5)
      expect(described_class.parse_dimension("-10")).to eq(-10.0)
    end
  end

  describe ".parse_view_box" do
    it "returns nil for missing or malformed" do
      expect(described_class.parse_view_box(nil)).to be_nil
      expect(described_class.parse_view_box("")).to be_nil
      expect(described_class.parse_view_box("1 2 3")).to be_nil
    end

    it "handles space or comma separators" do
      expect(described_class.parse_view_box("0 0 100 50")).to eq([0.0, 0.0, 100.0, 50.0])
      expect(described_class.parse_view_box("0,0,100,50")).to eq([0.0, 0.0, 100.0, 50.0])
    end
  end
end
