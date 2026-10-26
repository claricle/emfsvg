# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Compound pending clip topology" do
  let(:fixture) { File.binread(File.expand_path("../fixtures/emfsvg_golden/test-150.svg", __dir__)) }
  let(:geometry) do
    "M 0.0000,0.0000 L 4.0000,0.0000 L 4.0000,4.0000 L 0.0000,4.0000 L 0.0000,0.0000 Z " \
      "M 6.0000,0.0000 L 10.0000,0.0000 L 10.0000,4.0000 L 6.0000,4.0000 L 6.0000,0.0000 Z "
  end
  let(:draw) do
    '<path clip-path="url(#clip-16807)" d="M 0,0 L 10,0 L 10,4 Z" fill="#123456" stroke="none"/>'
  end
  let(:source) do
    <<~SVG
      <svg width="20" height="20"><g transform="translate(0.0000, 0.0000)">
      <path d="#{geometry}" fill="none" stroke="none" />
      <defs><clipPath id="clip-16807"><path d="#{geometry}Z" /></clipPath></defs>
      #{draw}#{draw}<rect x="15" y="15" width="2" height="2"/>
      </g></svg>
    SVG
  end
  let(:bytes) { Emfsvg.from_svg(source) }
  let(:wires) { Emf.parse(bytes).records.map(&:wire) }
  let(:output) { Emfsvg.from_bytes(bytes) }
  let(:clip) do
    document = Emfsvg::Svg::Parser.call(source)
    Emfsvg::Svg::ClipPathRegistry.from_document(document).lookup("url(#clip-16807)")
  end

  it "preserves test-150 byte for byte through serialized EMF" do
    emitted = Emfsvg.from_svg(fixture)
    expect(Emf.parse(emitted).errors).to be_empty
    expect(Emfsvg.from_bytes(emitted)).to eq(fixture)
  end

  it "selects all disjoint contours once and restores before an unrelated drawing" do
    expect(Emf.parse(bytes).errors).to be_empty
    expect(wires.grep(Emf::Emr::Binary::Records::SelectClipPath).size).to eq(1)
    expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect)).to be_empty
    expect(wires.grep(Emf::Emr::Binary::Records::PolyPolygon).size).to eq(1)
    expect(output.lines.grep(/\A<defs>/)).to eq(source.lines.grep(/\A<defs>/))
    expect(output.lines.grep(/\A<path /).grep(/clip-path/).size).to eq(2)
    expect(output.lines.grep(/\A<rect /).last).not_to include("clip-path")
    expect(wires.grep(Emf::Emr::Binary::Records::SaveDc).size)
      .to eq(wires.grep(Emf::Emr::Binary::Records::RestoreDc).size)
  end

  it "never recognizes a compound path as one rectangular clip" do
    expect(clip.clip_bounds).to be_nil
  end

  context "with a single rectangle" do
    let(:geometry) { "M 0.0000,0.0000 L 4.0000,0.0000 L 4.0000,4.0000 L 0.0000,4.0000 L 0.0000,0.0000 " }

    it "retains the exact rectangular optimization" do
      expect(clip.clip_bounds).to eq([0, 0, 4, 4])
    end
  end

  context "with a bow tie through the same four corners" do
    let(:geometry) { "M 0.0000,0.0000 L 4.0000,4.0000 L 4.0000,0.0000 L 0.0000,4.0000 L 0.0000,0.0000 " }

    it "does not infer a rectangular region from its bounding box" do
      expect(clip.clip_bounds).to be_nil
    end
  end

  context "with an inner contour in the opposite direction" do
    let(:geometry) do
      "M 0.0000,0.0000 L 10.0000,0.0000 L 10.0000,10.0000 L 0.0000,10.0000 L 0.0000,0.0000 Z " \
        "M 2.0000,2.0000 L 2.0000,8.0000 L 8.0000,8.0000 L 8.0000,2.0000 L 2.0000,2.0000 Z "
    end

    it "preserves the hole's contour and winding through the model serializer" do
      expect(clip.clip_bounds).to be_nil
      expect(output.lines.grep(/\A<defs>/)).to eq(source.lines.grep(/\A<defs>/))
      expect(wires.grep(Emf::Emr::Binary::Records::SelectClipPath).size).to eq(1)
    end
  end

  context "with ordinary clip path spelling" do
    let(:source) { super().sub(%(#{geometry}Z" />), %(#{geometry}Z"/>)) }

    it "does not select an unproven clip definition" do
      expect(wires.grep(Emf::Emr::Binary::Records::SelectClipPath)).to be_empty
    end
  end

  context "with ordinary pending spelling" do
    let(:source) { super().sub('fill="none" stroke="none" />', 'fill="none" stroke="none"/>') }

    it "does not infer a native selection" do
      expect(wires.grep(Emf::Emr::Binary::Records::SelectClipPath)).to be_empty
    end
  end

  context "with ordinary resource spelling" do
    let(:source) { super().gsub("clip-16807", "ordinary") }

    it "does not infer a native selection" do
      expect(wires.grep(Emf::Emr::Binary::Records::SelectClipPath)).to be_empty
    end
  end

  context "with different pending geometry" do
    let(:source) { super().sub('d="M 0.0000,0.0000', 'd="M 1.0000,0.0000') }

    it "does not select an unrelated pending path" do
      expect(wires.grep(Emf::Emr::Binary::Records::SelectClipPath)).to be_empty
    end
  end

  context "with an additional nonadjacent use" do
    let(:source) { super().sub("</g></svg>", "#{draw}</g></svg>") }

    it "does not carry selection across the unrelated drawing" do
      expect(wires.grep(Emf::Emr::Binary::Records::SelectClipPath)).to be_empty
    end
  end
end
