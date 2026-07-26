# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::Svg::Color do
  describe ".parse" do
    it "parses 6-digit hex" do
      c = described_class.parse("#FF8800")
      expect([c.red, c.green, c.blue]).to eq([255, 136, 0])
    end

    it "parses 3-digit hex by doubling each digit" do
      c = described_class.parse("#F80")
      expect([c.red, c.green, c.blue]).to eq([255, 136, 0])
    end

    it "parses case-insensitively" do
      expect(described_class.parse("#abcdef")).to eq(described_class.parse("#ABCDEF"))
    end

    it "parses rgb() functional notation" do
      c = described_class.parse("rgb(100, 50, 25)")
      expect([c.red, c.green, c.blue]).to eq([100, 50, 25])
    end

    it "parses CSS named colors" do
      c = described_class.parse("red")
      expect([c.red, c.green, c.blue]).to eq([255, 0, 0])
    end

    it "treats nil and 'none' as the NULL color" do
      expect(described_class.parse(nil)).to be_null
      expect(described_class.parse("none")).to be_null
      expect(described_class.parse("")).to be_null
    end

    it "rejects unsupported syntax" do
      expect { described_class.parse("currentColor") }.to raise_error(Emfsvg::FormatError)
      expect { described_class.parse("hsl(0, 0%, 0%)") }.to raise_error(Emfsvg::FormatError)
    end

    it "clamps out-of-range rgb values" do
      c = described_class.parse("rgb(999, -10, 0)")
      expect([c.red, c.green, c.blue]).to eq([255, 0, 0])
    end
  end

  describe "NULL constant" do
    it "is null and has zero RGB" do
      expect(described_class::NULL).to be_null
      expect([described_class::NULL.red, described_class::NULL.green, described_class::NULL.blue]).to eq([0, 0, 0])
    end

    it "equals other NULL references" do
      expect(described_class::NULL).to eq(described_class::NULL)
    end
  end
end
