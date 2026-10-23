# frozen_string_literal: true

require "spec_helper"
require "leptris"

RSpec.describe "serialized EMF handle table capacity" do
  let(:svg) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
        <rect x="1" y="2" width="10" height="20" fill="red"/>
        <circle cx="40" cy="40" r="10" fill="blue"/>
        <text x="5" y="70" font-size="12">Hi</text>
      </svg>
    SVG
  end

  it "includes reserved zero and every allocated pen, brush and font after deletion" do
    parsed = Emf.parse(Emfsvg.from_svg(svg))
    expect(parsed.errors).to be_empty
    handles = parsed.records.filter_map do |record|
      wire = record.wire
      case wire
      when Emf::Emr::Binary::Records::CreatePen then wire.ih_pen.to_i
      when Emf::Emr::Binary::Records::CreateBrushIndirect then wire.ih_brush.to_i
      when Emf::Emr::Binary::Records::CreateFontIndirectW,
           Emf::Emr::Binary::Records::SelectObject,
           Emf::Emr::Binary::Records::DeleteObject then wire.ih_object.to_i
      end
    end

    expect(handles.uniq.sort).to eq([1, 2, 3, 4, 5])
    expect(parsed.header.n_handles).to eq(6)
    expect(handles).to all(be < parsed.header.n_handles)
  end

  it "retains the reserved zero slot when no objects are created" do
    parsed = Emf.parse(Emfsvg.from_svg('<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"/>'))

    expect(parsed.errors).to be_empty
    expect(parsed.header.n_handles).to eq(1)
  end

  it "preserves rendered geometry, colors and text" do
    rendered = Leptris::XML.parse(Emfsvg.from_bytes(Emfsvg.from_svg(svg)))
    rect = rendered.at_xpath("//*[local-name()='rect']")
    ellipse = rendered.at_xpath("//*[local-name()='ellipse']")
    text = rendered.at_xpath("//*[local-name()='text']")

    expect(%w[x y width height fill].map { |key| rect[key] }).to eq(%w[1.0000 2.0000 10.0000 20.0000 #FF0000])
    expect(%w[cx cy rx ry fill].map { |key| ellipse[key] }).to eq(%w[40.0000 40.0000 10.0000 10.0000 #0000FF])
    expect(%w[x y font-size fill].map { |key| text[key] }).to eq(%w[5.0000 70.0000 12.0000 #000000])
    expect(text.text).to eq("Hi")
  end
end
