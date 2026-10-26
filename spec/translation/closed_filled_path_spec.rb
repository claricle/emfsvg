# frozen_string_literal: true

require "spec_helper"

RSpec.describe "closed filled SVG paths" do
  include Emfsvg::SpecSupport::ClosedFilledPathHelpers

  let(:path_data) do
    "M 900.0000,1300.0000 L 1200.0000,1500.0000 L 1200.0000,1700.0000 L 900.0000,1500.0000 Z "
  end

  let(:canonical_poly_polygon_path) do
    [
      %(<path d="#{path_data}"  fill="#C47FFF" ),
      %(stroke="#7FFFC4" stroke-width="50.0000"  stroke-linecap="square" ),
      %( stroke-linejoin="miter"  stroke-miterlimit="8.0000" />)
    ].join
  end

  it "preserves the canonical PolyPolygon record and formatting" do
    fixture_path = File.readlines("spec/fixtures/emfsvg_golden/test-039.svg")
                       .find { |line| line.include?(path_data) }.strip
    expect(canonical_poly_polygon_path).to eq(fixture_path)

    bytes = Emfsvg.from_svg(svg_with(canonical_poly_polygon_path))
    records = Emf.parse(bytes).records.map(&:wire)
    rendered_path = Emfsvg.from_bytes(bytes).lines.find { |line| line.start_with?("<path ") }.strip

    expect(records.grep(Emf::Emr::Binary::Records::PolyPolygon).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::Polygon)).to be_empty
    expect(rendered_path).to eq(canonical_poly_polygon_path)
  end

  it "keeps conventional closed paths on the Polygon record route" do
    polygon_path = [
      %(<path d="#{path_data.delete_suffix(' ')}" stroke="#7FFFC4" ),
      %(stroke-width="50.0000"  stroke-linecap="square"  stroke-linejoin="miter" ),
      %( stroke-miterlimit="8.0000" fill="#C47FFF" />)
    ].join
    bytes = Emfsvg.from_svg(svg_with(polygon_path))
    records = Emf.parse(bytes).records.map(&:wire)
    polygon_render = [
      %(<path d="#{path_data.delete_suffix(' ')}" stroke="#7FFFC4" stroke-width="50.0000"  ),
      %(stroke-linecap="square"  stroke-linejoin="miter"  stroke-miterlimit="8.0000"  fill="#C47FFF" />)
    ].join

    expect(records.grep(Emf::Emr::Binary::Records::Polygon).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::PolyPolygon)).to be_empty
    expect(Emfsvg.from_bytes(bytes)).to include(polygon_render)
  end
end
