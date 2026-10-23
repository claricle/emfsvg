# frozen_string_literal: true

require "spec_helper"

RSpec.describe "single-line SVG paths" do
  let(:svg) do
    <<~SVG
      <?xml version="1.0"  encoding="UTF-8" standalone="no"?>
      <svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="200.0000" height="200.0000">
      <g transform="translate(-0.0000, -0.0000)">
      <path d="M 0.0000,0.0000 L 100.0000,0.0000 " stroke="#000000" stroke-width="1.0000"  stroke-linecap="round"  stroke-linejoin="round"  fill="none" />
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

  it "preserves the distinct canonical Polyline spacing and record kind" do
    source = svg.sub('stroke-linejoin="round"  fill=', 'stroke-linejoin="round" fill=')
    bytes = Emfsvg.from_svg(source)
    parsed = Emf.parse(bytes)
    expect(parsed.errors).to be_empty
    records = parsed.records.map(&:wire)

    expect(records.grep(Emf::Emr::Binary::Records::Polyline).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::LineTo)).to be_empty
    expect(Emfsvg.from_bytes(bytes).lines.grep(/<path /)).to eq(source.lines.grep(/<path /))
  end

  it "uses byte offsets through nested groups after non-ASCII source text" do
    source = svg.sub('stroke-linejoin="round"  fill=', 'stroke-linejoin="round" fill=')
                .sub("<path ", "<desc>שלום</desc><g><g><path ")
                .sub('fill="none" />', 'fill="none" /></g></g>')
    bytes = Emfsvg.from_svg(source)
    parsed = Emf.parse(bytes)
    expect(parsed.errors).to be_empty

    expect(parsed.records.map(&:wire).grep(Emf::Emr::Binary::Records::Polyline).size).to eq(1)
    expect(Emfsvg.from_bytes(bytes)).to include('stroke-linejoin="round" fill="none" />')
  end

  [
    ['stroke-linejoin="round"  fill=', 'stroke-linejoin="round"   fill='],
    ['stroke="#000000" stroke-width="1.0000"', 'stroke-width="1.0000" stroke="#000000"'],
    ["M 0.0000,0.0000", "M 0,0"],
    ['fill="none" />', 'fill="none"/>']
  ].each do |before, after|
    it "retains ordinary line behavior for noncanonical spelling #{after.inspect}" do
      source = svg.sub('stroke-linejoin="round"  fill=', 'stroke-linejoin="round" fill=')
      source = source.sub(before.sub("  fill=", " fill="), after)
      parsed = Emf.parse(Emfsvg.from_svg(source))
      expect(parsed.errors).to be_empty

      expect(parsed.records.map(&:wire).grep(Emf::Emr::Binary::Records::LineTo).size).to eq(1)
      expect(parsed.records.map(&:wire).grep(Emf::Emr::Binary::Records::Polyline)).to be_empty
    end
  end

  it "keeps canonical multi-segment open paths as PolylineTo records" do
    multi_line_svg = svg.sub("L 100.0000,0.0000 ", "L 100.0000,0.0000 L 100.0000,50.0000 ")
    records = Emf.parse(Emfsvg.from_svg(multi_line_svg)).records.map(&:wire)

    expect(records.grep(Emf::Emr::Binary::Records::PolylineTo).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::Polyline)).to be_empty
    expect(records.grep(Emf::Emr::Binary::Records::LineTo)).to be_empty
  end
end
