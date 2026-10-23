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

  it "preserves explicit cosmetic pixels without changing geometry or text" do
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20">
        <path d="M0 0 L10 10" fill="none" stroke="#FF0000" stroke-width="1px"
              stroke-linecap="round" stroke-linejoin="round"/>
        <text x="1" y="12" font-size="8">A</text>
      </svg>
    SVG

    output = Emfsvg.from_bytes(Emfsvg.from_svg(svg))

    expect(output).to include('stroke-width="1px"')
    expect(output).to include('d="M 0.0000,0.0000 L 10.0000,10.0000 "')
    expect(output).to include('font-size="8.0000"')
    expect(output).to include('width="20.0000" height="20.0000"')
  end

  it "keeps identity scaling for ordinary unitless strokes" do
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20">
        <path d="M0 0 L10 10" fill="none" stroke="#FF0000" stroke-width="1"/>
      </svg>
    SVG

    output = Emfsvg.from_bytes(Emfsvg.from_svg(svg))

    expect(output).to include('stroke-width="1.0000"')
    expect(output).not_to include('stroke-width="1px"')
  end

  it "preserves cosmetic pixels for narrow geometry at a large origin" do
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="300020" height="20">
        <path d="M300000 0 L300010 10" fill="none" stroke="#FF0000" stroke-width="1px"
              stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
    SVG

    output = Emfsvg.from_bytes(Emfsvg.from_svg(svg))

    expect(output).to include("M 300000.0000,0.0000 L 300010.0000,10.0000")
    expect(output).to include('stroke-width="1px"')
  end

  it "falls back to identity when the geometry span would overflow cosmetic scaling" do
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="600020" height="20">
        <path d="M0 0 L600000 10" fill="none" stroke="#FF0000" stroke-width="1px"
              stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
    SVG

    output = Emfsvg.from_bytes(Emfsvg.from_svg(svg))

    expect(output).to include("M 0.0000,0.0000 L 600000.0000,10.0000")
    expect(output).to include('stroke-width="1.0000"')
  end
end
