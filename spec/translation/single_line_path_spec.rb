# frozen_string_literal: true

require "spec_helper"

RSpec.describe "single-line SVG paths" do
  let(:svg) do
    <<~SVG
      <?xml version="1.0"  encoding="UTF-8" standalone="no"?>
      <svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="200.0000" height="200.0000">
      <g transform="translate(-0.0000, -0.0000)">
      <path d="M 0.0000,0.0000 L 100.0000,0.0000 " stroke="#000000" stroke-width="1.0000"  stroke-linecap="round"  stroke-linejoin="round" fill="none" />
      </g>
      </svg>
    SVG
  end

  it "round-trips exact LineTo SVG formatting and preserves record kinds" do
    bytes = Emfsvg.from_svg(svg)
    records = Emf.parse(bytes).records.map(&:wire)
    rendered = Emfsvg.from_bytes(bytes)

    expect(records.grep(Emf::Emr::Binary::Records::MoveToEx).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::LineTo).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::Polyline)).to be_empty
    expected_path = [
      %(<path d="M 0.0000,0.0000 L 100.0000,0.0000 " ),
      %(stroke="#000000" stroke-width="1.0000"  stroke-linecap="round" ),
      %( stroke-linejoin="round"  fill="none" />)
    ].join
    expect(rendered).to include(expected_path)
  end

  it "keeps multi-segment open paths as Polyline records" do
    multi_line_svg = svg.sub("L 100.0000,0.0000 ", "L 100.0000,0.0000 L 100.0000,50.0000 ")
    records = Emf.parse(Emfsvg.from_svg(multi_line_svg)).records.map(&:wire)

    expect(records.grep(Emf::Emr::Binary::Records::Polyline).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::LineTo)).to be_empty
  end
end
