# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SVG path draw action selection" do
  let(:curve) { "M 2,2 C 4,2 4,8 6,8 L 2,8 Z" }

  def records_for(path)
    svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20">#{path}</svg>)
    Emf.parse(Emfsvg.from_svg(svg)).records.map(&:wire)
  end

  it "fills a C-rendered fill-only closed curve without stroking its outline" do
    source = File.read("spec/fixtures/golden/test-150.svg")
    path = source.lines.find do |line|
      line.start_with?("<path") && line.include?("M 505.0000,56.0000")
    end
    expect(path).to include('fill="#D9D9D9" stroke="none"')

    records = records_for(path.strip)

    expect(records.grep(Emf::Emr::Binary::Records::FillPath).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::StrokeAndFillPath)).to be_empty
    bytes = Emfsvg.from_svg(
      %(<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20">#{path.strip}</svg>)
    )
    expect(Emfsvg.from_bytes(bytes)).to include('fill="#D9D9D9" stroke="none"')
  end

  it "keeps the stroke-only and combined actions for their respective styles" do
    stroke_only = records_for(%(<path d="#{curve}" fill="none" stroke="#336699"/>))
    combined = records_for(%(<path d="#{curve}" fill="#C47FFF" stroke="#336699"/>))

    expect(stroke_only.grep(Emf::Emr::Binary::Records::StrokePath).size).to eq(1)
    expect(stroke_only.grep(Emf::Emr::Binary::Records::StrokeAndFillPath)).to be_empty
    expect(combined.grep(Emf::Emr::Binary::Records::StrokeAndFillPath).size).to eq(1)
  end
end
