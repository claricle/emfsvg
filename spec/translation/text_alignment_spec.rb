# frozen_string_literal: true

require "spec_helper"
require "leptris"

RSpec.describe "SVG text alignment roundtrip" do
  def roundtrip_texts(texts)
    bytes = Emfsvg.from_svg(<<~SVG)
      <svg xmlns="http://www.w3.org/2000/svg" width="800" height="600">
        #{texts}
      </svg>
    SVG
    parsed = Emf.parse(bytes)
    expect(parsed.errors).to be_empty
    output = Leptris::XML.parse(Emfsvg.from_bytes(bytes))
    [parsed, output.xpath("//*[local-name()='text']")]
  end

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

  it "resets alignment for explicit and omitted start anchors after centered and end text" do
    parsed, texts = roundtrip_texts(<<~SVG)
      <text x="10" y="20" font-size="10" text-anchor="middle">center</text>
      <text x="20" y="30" font-size="10" text-anchor="start">start</text>
      <text x="30" y="40" font-size="10" text-anchor="end">end</text>
      <text x="40" y="50" font-size="10">default</text>
    SVG

    align = parsed.records.map(&:wire).grep(Emf::Emr::Binary::Records::SetTextAlign)
    expect(align.map(&:text_align_mode)).to eq([0x1E, 0, 0x1A, 0])
    expect(texts.map { |text| [text["text-anchor"], text["y"]] })
      .to eq([["middle", "20.0000"], ["start", "30.0000"], ["end", "40.0000"], ["start", "50.0000"]])
    references = parsed.records.map(&:wire).grep(Emf::Emr::Binary::Records::ExtTextOutW)
    expect(references.map { |text| text.ptl_reference.y }).to eq([20, 21, 40, 41])
  end
end
