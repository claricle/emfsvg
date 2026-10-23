# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Clip intervals across unselected canonical patterns" do
  let(:fixture) { File.binread(File.expand_path("../fixtures/emfsvg_golden/test-005.svg", __dir__)) }
  let(:pattern) do
    index = fixture.lines.index { |line| line.start_with?('<defs><image id="img-1"') }
    fixture.lines.slice(index, 2).join
  end
  let(:source) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100" height="100">
      <g transform="translate(0.0000, 0.0000)">
      <defs><clipPath id="clip-16807"><path d="M 0.0000,0.0000 L 90.0000,0.0000 L 90.0000,90.0000 L 0.0000,90.0000 L 0.0000,0.0000 Z Z" /></clipPath></defs>
      <path clip-path="url(#clip-16807)" d="M 1,1 L 2,2" stroke="#ff0000" fill="none"/>
      <defs><clipPath id="clip-282475249"><path d="M 10.0000,10.0000 L 20.0000,10.0000 L 20.0000,20.0000 L 10.0000,20.0000 L 10.0000,10.0000 Z Z" /></clipPath></defs>
      <path clip-path="url(#clip-282475249)" d="M 11,11 L 12,12" stroke="#00ff00" fill="none"/>
      #{pattern}
      <path clip-path="url(#clip-16807)" d="M 3,3 L 4,4" stroke="#0000ff" fill="none"/>
      <path d="M 95,95 L 99,99" stroke="#000000" fill="none"/>
      </g></svg>
    SVG
  end
  let(:bytes) { Emfsvg.from_svg(source) }
  let(:wires) { Emf.parse(bytes).records.map(&:wire) }

  it "preserves all source bytes in test005 across the pattern definition" do
    wire = Emfsvg.from_svg(fixture)
    expect(Emf.parse(wire).errors).to be_empty
    expect(Emfsvg.from_bytes(wire).b).to eq(fixture)
  end

  it "creates the brush inside balanced clip scopes without clipping the successor" do
    expect(wires.grep(Emf::Emr::Binary::Records::CreateDibPatternBrushPt).size).to eq(1)
    expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(2)
    expect(wires.grep(Emf::Emr::Binary::Records::SaveDc).size)
      .to eq(wires.grep(Emf::Emr::Binary::Records::RestoreDc).size)
    output = Emfsvg.from_bytes(bytes)
    expect(output.scan("<clipPath ").size).to eq(2)
    expect(output.lines.grep(/\A<path /).last).not_to include("clip-path")
  end

  context "with an ordinary resource definition" do
    let(:pattern) { super().gsub("img-1", "ordinary") }

    it "retains the conservative clip boundaries" do
      expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(3)
      expect(wires.grep(Emf::Emr::Binary::Records::ExtSelectClipRgn)).to be_empty
      expect(Emfsvg.from_bytes(bytes).lines.grep(/\A<path /).last).not_to include("clip-path")
    end
  end

  context "with ordinary clip identifiers" do
    let(:source) { super().gsub("clip-16807", "outer").gsub("clip-282475249", "inner") }

    it "keeps every drawing in its independent clip scope" do
      expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(3)
      expect(wires.grep(Emf::Emr::Binary::Records::ExtSelectClipRgn)).to be_empty
    end
  end
end
