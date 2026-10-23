# frozen_string_literal: true

require "spec_helper"
require "leptris"

RSpec.describe Emfsvg::Translation::Handlers::TextHandler do
  let(:context) { Emfsvg::Translation::Context.new }

  it "emits CreateFontIndirectW + SetTextColor + ExtTextOutW + SelectObject + DeleteObject" do
    element = Emfsvg::Svg::Element.from_node(
      Leptris::XML.parse('<text x="10" y="20" font-family="Arial" font-size="14" fill="#000000">Hello</text>').root
    )
    described_class.call(element, context)

    wire_classes = context.records.map { |r| r.wire.class }
    expect(wire_classes).to include(Emf::Emr::Binary::Records::CreateFontIndirectW)
    expect(wire_classes).to include(Emf::Emr::Binary::Records::SetTextColor)
    expect(wire_classes).to include(Emf::Emr::Binary::Records::ExtTextOutW)
    expect(wire_classes).to include(Emf::Emr::Binary::Records::DeleteObject)
  end

  it "encodes text content as UTF-16LE in the trailing bytes" do
    element = Emfsvg::Svg::Element.from_node(
      Leptris::XML.parse('<text x="0" y="0" font-family="Arial" font-size="12" fill="#000000">Hi</text>').root
    )
    described_class.call(element, context)
    extext = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::ExtTextOutW) }
    expect(extext.wire.n_chars).to eq(2)
    # Trailing starts with UTF-16LE "Hi" = 0x48 0x00 0x69 0x00
    expect(extext.wire.trailing.bytes[0, 4]).to eq([0x48, 0x00, 0x69, 0x00])
  end

  it "skips empty content" do
    element = Emfsvg::Svg::Element.from_node(
      Leptris::XML.parse('<text x="0" y="0" font-family="Arial" font-size="12" fill="#000000"></text>').root
    )
    described_class.call(element, context)
    expect(context.records).to be_empty
  end
end

RSpec.describe "SVG text record alignment" do
  ["abc", "abcd", "«FeatureType»", "Veglenke"].each do |text|
    it "preserves #{text.inspect} through EMF parsing and SVG rendering" do
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="50">
          <text x="1" y="20" font-family="Calibri" font-size="10">#{text}</text>
        </svg>
      SVG
      bytes = Emfsvg.from_svg(svg)
      parsed = Emf.parse(bytes)

      expect(parsed.errors).to be_empty
      record = parsed.records.map(&:wire).find { |wire| wire.is_a?(Emf::Emr::Binary::Records::ExtTextOutW) }
      expect(record).not_to be_nil
      expect(record.n_chars).to eq(text.length)
      expect(record.off_dx % 4).to eq(0)
      expect(record.n_size % 4).to eq(0)
      expect(record.n_size).to eq(record.to_binary_s.bytesize)
      expect(record.n_size).to eq(record.off_dx + (4 * text.length))
      expect(record.trailing.byteslice(0, text.length * 2)).to eq(text.encode("UTF-16LE").b)
      expect(Emfsvg.from_bytes(bytes)).to include("<![CDATA[#{text}]]>")
    end
  end
end
