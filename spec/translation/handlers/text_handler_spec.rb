# frozen_string_literal: true

require "spec_helper"
require "nokogiri"

RSpec.describe Emfsvg::Translation::Handlers::TextHandler do
  let(:context) { Emfsvg::Translation::Context.new }

  it "emits CreateFontIndirectW + SetTextColor + ExtTextOutW + SelectObject + DeleteObject" do
    element = Emfsvg::Svg::Element.from_node(
      Nokogiri::XML('<text x="10" y="20" font-family="Arial" font-size="14" fill="#000000">Hello</text>').root
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
      Nokogiri::XML('<text x="0" y="0" font-family="Arial" font-size="12" fill="#000000">Hi</text>').root
    )
    described_class.call(element, context)
    extext = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::ExtTextOutW) }
    expect(extext.wire.n_chars).to eq(2)
    # Trailing starts with UTF-16LE "Hi" = 0x48 0x00 0x69 0x00
    expect(extext.wire.trailing.bytes[0, 4]).to eq([0x48, 0x00, 0x69, 0x00])
  end

  it "skips empty content" do
    element = Emfsvg::Svg::Element.from_node(
      Nokogiri::XML('<text x="0" y="0" font-family="Arial" font-size="12" fill="#000000"></text>').root
    )
    described_class.call(element, context)
    expect(context.records).to be_empty
  end
end
