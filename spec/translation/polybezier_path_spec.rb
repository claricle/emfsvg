# frozen_string_literal: true

require "spec_helper"
require "leptris"

RSpec.describe "SVG PolyBezier path preservation" do
  def roundtrip_path(data, fill: "none")
    bytes = Emfsvg.from_svg(<<~SVG)
      <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
        <path d="#{data}" fill="#{fill}" stroke="#000000"/>
      </svg>
    SVG
    parsed = Emf.parse(bytes)
    expect(parsed.errors).to be_empty
    output = Emfsvg.from_bytes(bytes)
    [parsed.records.map(&:wire), output, Leptris::XML.parse(output).xpath("//*[local-name()='path']")]
  end

  it "preserves the preceding current point and cubic path drawing operation" do
    records, output, paths = roundtrip_path("M 3 4 M 10 20 C 30 40 50 60 70 80 C 50 60 30 40 10 20")

    expect(records.grep(Emf::Emr::Binary::Records::PolyBezier).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::BeginPath)).to be_empty
    expected = "M 3.0000,4.0000 M 10.0000,20.0000 C 30.0000,40.0000 50.0000,60.0000 70.0000,80.0000 " \
               "C 50.0000,60.0000 30.0000,40.0000 10.0000,20.0000 "
    expect(paths.map { |path| path["d"] }).to eq([expected])
    expect(output.lines.find { |line| line.start_with?("<path ") }).to match(%r{stroke=.*  fill="none" />\n\z})
  end

  it "retains filling for an empty move followed by a filled cubic figure" do
    records, _, paths = roundtrip_path("M 3 4 M 10 20 C 30 40 50 60 70 80", fill: "red")

    expect(records.grep(Emf::Emr::Binary::Records::PolyBezier)).to be_empty
    expect(records.grep(Emf::Emr::Binary::Records::StrokeAndFillPath).size).to eq(1)
    expect(paths.first["fill"]).to eq("#FF0000")
  end

  {
    "separate cubic figures" => "M 1 2 C 3 4 5 6 7 8 M 10 20 C 30 40 50 60 70 80",
    "a closed cubic figure" => "M 3 4 M 10 20 C 30 40 50 60 70 80 Z",
    "a mixed cubic and line figure" => "M 3 4 M 10 20 C 30 40 50 60 70 80 L 90 95"
  }.each do |description, data|
    it "preserves the general path operation for #{description}" do
      records, _, paths = roundtrip_path(data)

      expect(records.grep(Emf::Emr::Binary::Records::PolyBezier)).to be_empty
      expect(records.grep(Emf::Emr::Binary::Records::StrokeAndFillPath).size).to eq(1)
      expect(paths.size).to eq(1)
      expect(paths.first["d"]).to include("C ")
      expect(paths.first["d"].include?("Z")).to eq(data.end_with?("Z"))
    end
  end
end
