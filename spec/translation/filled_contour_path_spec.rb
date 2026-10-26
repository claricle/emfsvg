# frozen_string_literal: true

require "spec_helper"

RSpec.describe "canonical fill-only contour provenance" do
  include Emfsvg::SpecSupport::CanonicalPathConversion

  let(:source_lines) { File.readlines("spec/fixtures/emfsvg_golden/test-186.svg") }

  ["M 15.2144,22.1004", "M 129.9479,25.1236", "M 132.3447,27.6255"].each do |start|
    it "preserves FillPath geometry and paint for #{start}" do
      path = source_lines.find { |line| line.start_with?(%(<path d="#{start})) }.strip
      records, output = convert(path)

      expect(records.grep(Emf::Emr::Binary::Records::FillPath).size).to eq(1)
      expect(records.grep(Emf::Emr::Binary::Records::Polygon)).to be_empty
      expect(records.grep(Emf::Emr::Binary::Records::PolyPolygon)).to be_empty
      expect(output.lines.find { |line| line.start_with?("<path ") }.strip).to eq(path)
    end
  end

  it "retains the Polygon strategy for ordinary fill-only SVG contours" do
    records, output = convert('<path d="M 1,2 L 3,4 L 5,2 Z" fill="#336699" stroke="none"/>')

    expect(records.grep(Emf::Emr::Binary::Records::Polygon).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::FillPath)).to be_empty
    expected = '<path d="M 1.0000,2.0000 L 3.0000,4.0000 L 5.0000,2.0000 Z" ' \
               'stroke-width="1px" stroke="#336699"  fill="#336699" />'
    expect(output.lines.find { |line| line.start_with?("<path ") }.strip).to eq(expected)
  end

  it "requires the exact renderer spelling before recovering contour provenance" do
    path = source_lines.find { |line| line.start_with?('<path d="M 129.9479,25.1236') }.strip
    records, = convert(path.sub("  fill=", " fill="))

    expect(records.grep(Emf::Emr::Binary::Records::Polygon).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::FillPath)).to be_empty
  end
end
