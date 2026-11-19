# frozen_string_literal: true

require "base64"
require "spec_helper"

# The 2x2 palette PNG tile used by the EA-PDF specification figures,
# and a second 8x8 tile for distinct-pattern coverage.
TILE_PNG = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0k" \
           "AAAACklEQVR4AWPAAAAAEgABKPhxBgAAAABJRU5ErkJggg=="
SECOND_TILE_PNG = "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAALklEQVQYlc3OoQ0AMAwD" \
                  "wf/sv7NDqqqkwTGzzsBCknCj8PaaUKEmTM7ghwAu+NCtxSQHJKY49QAAAABJRU5ErkJgggAA"

# General (non-canonical) SVG pattern fills as authored by arbitrary
# tools (Visio exports, the pdf-association/spec-ea-pdf figures):
# a <pattern> paint server with a raster tile, referenced through
# fill="url(#id)". Unlike the canonical img-N-ref round-trip form,
# tile dimensions live in SVG user units and need not match the
# embedded bitmap's pixel size.
RSpec.describe "General pattern fills" do
  def pattern_def(id, png)
    <<~SVG
      <pattern id="#{id}" width="100%" height="100%" viewBox="0 0 1 1" preserveAspectRatio="xMidYMid slice">
        <image width="1" height="1" href="data:image/png;base64,#{png}"/>
      </pattern>
    SVG
  end

  let(:svg) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
           width="200" height="160" viewBox="0 0 200 160">
        <defs>
          <clipPath id="clipPath1"><rect x="0" y="0" width="200" height="160"/></clipPath>
          #{pattern_defs}
        </defs>
        <g clip-path="url(#clipPath1)">
          #{draws}
        </g>
      </svg>
    SVG
  end

  let(:pattern_defs) { pattern_def("pattern23", TILE_PNG) }
  let(:draws) { %(<rect fill="url(#pattern23)" x="10" y="10" width="137" height="137"/>) }

  let(:bytes) { Emfsvg.from_svg(svg) }
  let(:wires) { Emf.parse(bytes).records.map(&:wire) }
  let(:brushes) { wires.grep(Emf::Emr::Binary::Records::CreateDibPatternBrushPt) }
  let(:selections) { wires.grep(Emf::Emr::Binary::Records::SelectObject).map { |w| w.ih_object.to_i } }

  it "translates the referenced fill without raising" do
    expect { bytes }.not_to raise_error
  end

  it "creates a DIB pattern brush from the referenced raster tile" do
    decoded = Emfsvg::PngDecoder.decode(Base64.decode64(TILE_PNG))
    expect(brushes.size).to eq(1)
    expect(brushes.first.body)
      .to eq(Emfsvg::DibEncoder.encode(decoded.width, decoded.height, decoded.pixels))
  end

  it "selects the registered brush for the filled draw" do
    handle = brushes.first.ih_brush.to_i
    expect(selections.count(handle)).to eq(1)
  end

  it "round-trips through the renderer" do
    expect { Emfsvg.from_bytes(bytes) }.not_to raise_error
  end

  context "with several distinct referenced patterns" do
    let(:pattern_defs) do
      pattern_def("pattern9", TILE_PNG) + pattern_def("pattern11", SECOND_TILE_PNG)
    end
    let(:draws) do
      %(<rect fill="url(#pattern9)" x="1" y="2" width="30" height="40"/>) +
        %(<path fill="url(#pattern11)" d="M 50,2 L 80,2 L 80,42 L 50,42 Z"/>)
    end

    it "registers one brush per pattern and selects each" do
      expect(brushes.size).to eq(2)
      handles = brushes.map { |b| b.ih_brush.to_i }
      expect(handles.uniq.size).to eq(2)
      handles.each { |handle| expect(selections.count(handle)).to eq(1) }
    end
  end

  context "with a pattern reused by several draws" do
    let(:draws) do
      %(<rect fill="url(#pattern23)" x="1" y="2" width="30" height="40"/>) +
        %(<ellipse fill="url(#pattern23)" cx="100" cy="80" rx="20" ry="10"/>)
    end

    it "reuses the single brush definition" do
      expect(brushes.size).to eq(1)
      handle = brushes.first.ih_brush.to_i
      expect(selections.count(handle)).to eq(2)
    end
  end

  context "with an unresolvable reference (no such pattern id)" do
    let(:pattern_defs) { "" }
    let(:draws) { %(<rect fill="url(#pattern-absent)" x="1" y="2" width="30" height="40"/>) }

    it "degrades to a solid black brush instead of failing" do
      expect { bytes }.not_to raise_error
      expect(brushes).to be_empty

      solid = wires.grep(Emf::Emr::Binary::Records::CreateBrushIndirect)
      expect(solid.size).to eq(1)
      expect(solid.first.brush_style).to eq(Emfsvg::Svg::Paint::SOLID)
      expect(solid.first.color.red).to eq(0)
      expect(solid.first.color.green).to eq(0)
      expect(solid.first.color.blue).to eq(0)
    end

    it "warns about the degraded fill" do
      expect { Emfsvg.from_svg(svg) }
        .to output(%(emfsvg: unresolved SVG paint reference "pattern-absent"; fill degraded to solid black\n))
        .to_stderr
    end
  end

  context "with a gradient paint server the translation cannot map" do
    let(:pattern_defs) do
      <<~SVG
        <linearGradient id="grad1">
          <stop offset="0" stop-color="#ff0000"/>
          <stop offset="1" stop-color="#0000ff"/>
        </linearGradient>
      SVG
    end
    let(:draws) { %(<rect fill="url(#grad1)" x="1" y="2" width="30" height="40"/>) }

    it "degrades to a solid brush instead of failing the translation" do
      expect { bytes }.not_to raise_error
      expect(brushes).to be_empty
      expect(wires.grep(Emf::Emr::Binary::Records::CreateBrushIndirect)).not_to be_empty
    end
  end

  context "with a pattern whose tile is not a PNG raster" do
    let(:pattern_defs) do
      <<~SVG
        <pattern id="pattern-vec" width="10" height="10" patternUnits="userSpaceOnUse">
          <rect width="10" height="10" fill="#00ff00"/>
        </pattern>
      SVG
    end
    let(:draws) { %(<rect fill="url(#pattern-vec)" x="1" y="2" width="30" height="40"/>) }

    it "does not create a brush and degrades the fill" do
      expect { bytes }.not_to raise_error
      expect(brushes).to be_empty
      expect(wires.grep(Emf::Emr::Binary::Records::CreateBrushIndirect)).not_to be_empty
    end
  end
end
