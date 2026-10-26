# frozen_string_literal: true

require "spec_helper"
require "leptris"

RSpec.describe "SVG text alignment roundtrip" do
  include Emfsvg::SpecSupport::TextAlignmentHelpers

  { "middle" => 0x1E, "end" => 0x1A }.each do |anchor, mode|
    it "preserves #{anchor} anchoring and the SVG baseline at integer font size" do
      parsed, texts = roundtrip_texts(<<~SVG)
        <text x="150" y="524" font-family="Arial" font-size="16" text-anchor="#{anchor}">10</text>
      SVG

      align = parsed.records.map(&:wire).grep(Emf::Emr::Binary::Records::SetTextAlign)
      expect(align.map(&:text_align_mode)).to eq([mode])
      expect(texts.map { |text| [text["text-anchor"], text["x"], text["y"], text.text] })
        .to eq([[anchor, "150.0000", "524.0000", "10"]])
    end

    it "preserves #{anchor} anchoring and a fractional transformed baseline" do
      _, texts = roundtrip_texts(<<~SVG)
        <text x="150.25" y="524.75" font-size="16" text-anchor="#{anchor}" transform="translate(2, 3)">abc</text>
      SVG

      expect(texts.map { |text| [text["text-anchor"], text["x"], text["y"]] })
        .to eq([[anchor, "150.2500", "524.7500"]])
    end
  end

  [nil, "start"].each do |anchor|
    it "preserves #{anchor || 'omitted'} anchoring without rounding a font-height adjustment" do
      attribute = anchor ? 'text-anchor="start"' : ""
      _, texts = roundtrip_texts(<<~SVG)
        <text x="237" y="12" font-size="13" #{attribute}>0</text>
        <text x="20" y="30" font-size="10" #{attribute}>control</text>
      SVG

      expect(texts.map { |text| [text["text-anchor"], text["x"], text["y"], text.text] })
        .to eq([["start", "237.0000", "12.0000", "0"],
                ["start", "20.0000", "30.0000", "control"]])

      _, transformed = roundtrip_texts(<<~SVG)
        <text x="150.25" y="524.75" font-size="13" #{attribute} transform="translate(2, 3)">abc</text>
      SVG
      expect(transformed.map { |text| [text["text-anchor"], text["x"], text["y"], text.text] })
        .to eq([["start", "150.2500", "524.7500", "abc"]])
    end
  end

  it "resets alignment for explicit and omitted start anchors after centered and end text" do
    parsed, texts = roundtrip_texts(<<~SVG)
      <text x="10" y="20" font-size="10" text-anchor="middle">center</text>
      <text x="20" y="30" font-size="10" text-anchor="start">start</text>
      <text x="30" y="40" font-size="10" text-anchor="end">end</text>
      <text x="40" y="50" font-size="10">default</text>
    SVG

    align = parsed.records.map(&:wire).grep(Emf::Emr::Binary::Records::SetTextAlign)
    expect(align.map(&:text_align_mode)).to eq([0x1E, 0x18, 0x1A, 0x18])
    expect(texts.map { |text| [text["text-anchor"], text["y"]] })
      .to eq([["middle", "20.0000"], ["start", "30.0000"], ["end", "40.0000"], ["start", "50.0000"]])
    references = parsed.records.map(&:wire).grep(Emf::Emr::Binary::Records::ExtTextOutW)
    expect(references.map { |text| text.ptl_reference.y }).to eq([20, 30, 40, 50])
  end
  { "start" => ["18.0000", "283.0000", "297.4000"],
    "middle" => ["56.0000", "448.0000", "462.4000"],
    "end" => ["56.0000", "431.0000", "445.4000"] }.each do |anchor, (x, y, center_y)|
    it "preserves canonical rotated #{anchor} text without applying the baseline offset twice" do
      transform = "rotate(-90, #{x}, #{center_y}) translate(0, 14.4000)"
      _, texts = roundtrip_texts(<<~SVG)
        <text x="#{x}" y="#{y}" font-size="16" text-anchor="#{anchor}" transform="#{transform}">frequency</text>
        <text x="20" y="30" font-size="10">control</text>
      SVG

      expect(texts.map { |text| [text["transform"], text["x"], text["y"], text["text-anchor"], text.text] })
        .to eq([[transform, x, y, anchor, "frequency"], [nil, "20.0000", "30.0000", "start", "control"]])
      expect(texts.first.parent).to eq(texts.last.parent)
    end
  end

  [-35, -180].each do |angle|
    it "preserves a canonical #{angle} degree font rotation" do
      transform = "rotate(#{angle}, 18.0000, 297.4000) translate(0, 14.4000)"
      _, texts = roundtrip_texts(<<~SVG)
        <text x="18" y="283" font-size="16" transform="#{transform}">rotated</text>
      SVG
      expect([texts.first["transform"], texts.first["y"], texts.first.text])
        .to eq([transform, "283.0000", "rotated"])
    end
  end

  [
    ["rotate(-90, 18.0000, 297.5000) translate(0, 14.4000)", "",
     "matrix(0.0000 -1.0000 1.0000 0.0000 -265.1000 315.5000)"],
    ["rotate(-90, 18.0000, 297.4000) translate(0, 14.5000)", "",
     "matrix(0.0000 -1.0000 1.0000 0.0000 -264.9000 315.4000)"],
    ["rotate(-90, 18.0000, 297.4000) translate(0, 14.4000)", 'dy="2"',
     "matrix(0.0000 -1.0000 1.0000 0.0000 -265.0000 315.4000)"],
    ["translate(2, 3)", "", "matrix(1.0000 0.0000 0.0000 1.0000 2.0000 3.0000)"]
  ].each do |transform, extra, matrix|
    it "keeps #{transform} #{extra} on the general transform path" do
      _, texts = roundtrip_texts(<<~SVG)
        <text x="18" y="283" font-size="16" transform="#{transform}" #{extra}>arbitrary</text>
      SVG

      expect(texts.first["transform"]).to be_nil
      expect(texts.first.parent["transform"]).to eq(matrix)
      expect([texts.first["x"], texts.first["y"], texts.first.text]).to eq(["18.0000", "283.0000", "arbitrary"])
    end
  end
end
