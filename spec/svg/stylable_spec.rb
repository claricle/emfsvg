# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::Svg::Elements::Stylable do
  def node(attrs)
    Struct.new(:attrs) do
      def [](name) = attrs[name]
    end.new(attrs)
  end

  it "shares one fill and stroke between elements with the same attributes" do
    attrs = { "fill" => "#102030", "stroke" => "#C0C0C0", "stroke-width" => "2" }
    first = described_class.parse_style(node(attrs.dup))
    second = described_class.parse_style(node(attrs.dup))

    expect(second[:fill]).to equal(first[:fill])
    expect(second[:stroke]).to equal(first[:stroke])
  end

  it "keeps distinct attributes apart and parses them correctly" do
    thin = described_class.parse_style(node("stroke" => "#000000", "stroke-width" => "1"))
    thick = described_class.parse_style(node("stroke" => "#000000", "stroke-width" => "3"))

    expect([thin[:stroke].width, thick[:stroke].width]).to eq([1.0, 3.0])
    expect(thick[:stroke]).not_to equal(thin[:stroke])
  end

  it "keeps the per-element clip-path out of the shared pair" do
    a = described_class.parse_style(node("fill" => "red", "clip-path" => "url(#a)"))
    b = described_class.parse_style(node("fill" => "red", "clip-path" => "url(#b)"))

    expect([a[:clip_path], b[:clip_path]]).to eq(["url(#a)", "url(#b)"])
  end

  it "still rejects an unsupported colour, without remembering it" do
    bad = node("fill" => "notacolor")

    2.times { expect { described_class.parse_style(bad) }.to raise_error(Emfsvg::FormatError) }
  end

  it "includes miter limits in the shared paint identity" do
    low = { "stroke" => "#000000", "stroke-width" => "2", "stroke-miterlimit" => "3" }
    high = { "stroke" => "#000000", "stroke-width" => "2", "stroke-miterlimit" => "8" }
    strokes = [low, high].map { |element| described_class.parse_style(element)[:stroke] }

    expect(strokes.map(&:miter_limit)).to eq([3.0, 8.0])
    expect(strokes.first).not_to equal(strokes.last)
  end

  it "retains fill-dependent cosmetic stroke parsing in the cache" do
    filled = { "fill" => "#FFFFFF", "stroke" => "#000000", "stroke-width" => "1px" }
    empty = { "fill" => "none", "stroke" => "#000000", "stroke-width" => "1px" }
    first = described_class.parse_style(filled)
    second = described_class.parse_style(empty)

    expect(first[:stroke]).not_to equal(second[:stroke])
    expect(first[:fill].null?).to be(false)
    expect(second[:fill].null?).to be(true)
  end
end
