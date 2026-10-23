# frozen_string_literal: true

require "spec_helper"

RSpec.describe "cosmetic pen round-trip parity" do
  it "keeps a 1px colored stroke when the shape has no fill" do
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20">
        <path d="M0 0 L10 10" fill="none" stroke="#FF0000" stroke-width="1px"/>
      </svg>
    SVG

    output = Emfsvg.from_bytes(Emfsvg.from_svg(svg))

    expect(output).to include('stroke="#FF0000"')
    expect(output).not_to include('stroke="none"')
  end

  it "keeps the 1px null-pen fallback for a matching solid fill" do
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20">
        <path d="M0 0 L10 10" fill="#123456" stroke="#123456" stroke-width="1px"/>
      </svg>
    SVG

    output = Emfsvg.from_bytes(Emfsvg.from_svg(svg))

    expect(output).to include('stroke-width="1px" stroke="#123456"')
  end

  it "keeps an explicit round-capped pixel stroke cosmetic" do
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20">
        <path d="M0 0 L10 10" fill="none" stroke="#FF0000" stroke-width="1px"
              stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
    SVG

    stroke = Emfsvg::Svg::Parser.call(svg).root_element.children.first.stroke

    expect(stroke.pen_style & Emfsvg::Svg::Stroke::PS_GEOMETRIC).to eq(0)
  end
end
