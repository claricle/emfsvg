# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Filled rectangle translation" do
  it "preserves fill-only bounds without introducing an outline, including zero width" do
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">' \
          '<rect x="10" y="20" width="30" height="40" fill="#FFFF00"/>' \
          '<rect x="50" y="20" width="0" height="40" fill="#0000FF"/></svg>'
    bytes = Emfsvg.from_svg(svg)
    output = Emfsvg.from_bytes(bytes)
    records = Emf.parse(bytes).records.map(&:wire)

    fills = records.grep(Emf::Emr::Binary::Records::BitBlt)
    bounds = fills.map do |record|
      [record.x_dest.to_i, record.y_dest.to_i, record.cx_dest.to_i, record.cy_dest.to_i]
    end
    expect(bounds).to eq([[10, 20, 30, 40], [50, 20, 0, 40]])
    expect(output).to include('<rect x="10" y="20" width="30" height="40" fill="#FFFF00"/>',
                              '<rect x="50" y="20" width="0" height="40" fill="#0000FF"/>')
    expect(output).not_to include("stroke-width=")
  end

  it "retains an explicitly stroked rectangle" do
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">' \
          '<rect x="10" y="20" width="30" height="40" fill="#FFFF00" stroke="#FF0000" stroke-width="2"/></svg>'
    bytes = Emfsvg.from_svg(svg)
    records = Emf.parse(bytes).records.map(&:wire)

    expect(records.grep(Emf::Emr::Binary::Records::Rectangle).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::BitBlt)).to be_empty
    expect(Emfsvg.from_bytes(bytes)).to include('stroke="#FF0000" stroke-width="2.0000"')
  end

  it "retains clipping on a fill-only rectangle" do
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">' \
          '<defs><clipPath id="c"><rect x="15" y="25" width="10" height="10"/></clipPath></defs>' \
          '<rect x="10" y="20" width="30" height="40" fill="yellow" clip-path="url(#c)"/></svg>'
    bytes = Emfsvg.from_svg(svg)
    records = Emf.parse(bytes).records.map(&:wire)

    expect(records.grep(Emf::Emr::Binary::Records::Rectangle).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::BitBlt)).to be_empty
    expect(Emfsvg.from_bytes(bytes)).to include('clip-path="url(#clip')
  end
end
