# frozen_string_literal: true

require "spec_helper"
require "leptris"

RSpec.describe "canonical text rotation provenance" do
  [
    ["top", "412.8769", "87.4310", "41.5784", "-35", "87.4310", "37.4206", 0],
    ["truncated zero", "412.8769", "87.4310", "41.5784", "0", "87.4310", "37.4206", 0],
    ["fractional baseline", "32.5641", "119.8821", "29.9705", "-90", "146.8556", "26.9735", 24],
    ["existing fractional", "17.9564", "293.9910", "11.9910", "-90", "304.7829", "10.7919", 24]
  ].each do |label, x, y, size, angle, pivot, offset, alignment|
    context label do
      let(:transform) { "rotate(#{angle}, #{x}, #{pivot}) translate(0, #{offset})" }
      let(:bytes) do
        Emfsvg.from_svg(<<~SVG)
          <svg width="800" height="600">
            <text x="#{x}" y="#{y}" font-size="#{size}" transform="#{transform}">rotated</text>
            <text x="20" y="30" font-size="10">control</text>
          </svg>
        SVG
      end
      let(:parsed) { Emf.parse(bytes) }
      let(:texts) { Leptris::XML.parse(Emfsvg.from_bytes(bytes)).xpath("//*[local-name()='text']") }

      it "preserves the public roundtrip and ordinary following text" do
        expect(parsed.errors).to be_empty
        expect(texts.map { |text| [text["x"], text["y"], text["font-size"], text["transform"], text.text] })
          .to eq([[x, y, size, transform, "rotated"], ["20.0000", "30.0000", "10.0000", nil, "control"]])
        expect(texts.first.parent).to eq(texts.last.parent)
        aligns = parsed.records.map(&:wire).grep(Emf::Emr::Binary::Records::SetTextAlign)
        expect(aligns.map(&:text_align_mode)).to eq([alignment, 24])
      end
    end
  end

  it "reuses identical top text state and separates a baseline alignment change" do
    top = '<text x="20" y="30" font-size="10" transform="rotate(-90, 20.0000, 30.0000) translate(0, 9.0000)">top</text>'
    baseline = top.sub("30.0000)", "39.0000)").sub(">top<", ">baseline<")
    bytes = Emfsvg.from_svg(%(<svg width="100" height="100">#{top * 2}#{baseline * 2}</svg>))
    parsed = Emf.parse(bytes)
    expect(parsed.errors).to be_empty
    wires = parsed.records.map(&:wire)
    expect(wires.grep(Emf::Emr::Binary::Records::CreateFontIndirectW).size).to eq(2)
    expect(wires.grep(Emf::Emr::Binary::Records::SetTextAlign).map(&:text_align_mode)).to eq([0, 24])
    texts = Leptris::XML.parse(Emfsvg.from_bytes(bytes)).xpath("//*[local-name()='text']")
    expect(texts.map { |text| [text["y"], text["transform"], text.text] }).to eq(
      ([["30.0000", "rotate(-90, 20.0000, 30.0000) translate(0, 9.0000)", "top"]] * 2) +
      ([["30.0000", "rotate(-90, 20.0000, 39.0000) translate(0, 9.0000)", "baseline"]] * 2)
    )
  end

  it "preserves the positive 270 degree test-001 transform on the general affine path" do
    bytes = Emfsvg.from_svg(<<~SVG)
      <svg width="800" height="600">
        <text x="17.9564" y="293.9910" font-size="11.9910"
              transform="rotate(270, 17.9564, 304.7829) translate(0, 10.7919)">positive</text>
      </svg>
    SVG
    expect(Emf.parse(bytes).errors).to be_empty
    text = Leptris::XML.parse(Emfsvg.from_bytes(bytes)).at_xpath("//*[local-name()='text']")
    expect([text["x"], text["y"], text["font-size"], text["transform"], text.text])
      .to eq(["17.9564", "293.9910", "11.9910", nil, "positive"])
    expect(text.parent["transform"]).to eq("matrix(-0.0000 -1.0000 1.0000 -0.0000 -276.0346 322.7393)")
  end

  [
    ["rotate(-90, 32.5641, 146.8558) translate(0, 26.9735)", "0.0000 -1.0000 1.0000 0.0000 -87.3182 179.4199"],
    ["rotate(-90, 32.5641, 146.8556) translate(0, 26.9736)", "0.0000 -1.0000 1.0000 0.0000 -87.3179 179.4197"],
    ["rotate(-90, 32.5642, 146.8556) translate(0, 26.9735)", "0.0000 -1.0000 1.0000 0.0000 -87.3179 179.4198"],
    ["rotate(0, 32.5641, 119.8823) translate(0, 26.9735)", "1.0000 0.0000 0.0000 1.0000 0.0000 26.9735"]
  ].each do |transform, matrix|
    it "preserves nearby noncanonical #{transform} as an affine transform" do
      bytes = Emfsvg.from_svg(<<~SVG)
        <svg width="800" height="600">
          <text x="32.5641" y="119.8821" font-size="29.9705" transform="#{transform}">affine</text>
        </svg>
      SVG
      parsed = Emf.parse(bytes)
      expect(parsed.errors).to be_empty
      text = Leptris::XML.parse(Emfsvg.from_bytes(bytes)).at_xpath("//*[local-name()='text']")
      expect(text["transform"]).to be_nil
      expect(text.parent["transform"]).to eq("matrix(#{matrix})")
      expect([text["x"], text["y"], text["font-size"], text.text])
        .to eq(["32.5641", "119.8821", "29.9705", "affine"])
      expect(parsed.records.map(&:wire).grep(Emf::Emr::Binary::Records::SetWorldTransform).size).to eq(1)
    end
  end
end
