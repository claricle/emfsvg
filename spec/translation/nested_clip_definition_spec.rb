# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Canonical clip definitions across sibling groups" do
  let(:fixture) { File.read(File.expand_path("../fixtures/emfsvg_golden/EA-test-file-102.svg", __dir__)) }
  let(:bytes) { Emfsvg.from_svg(fixture) }
  let(:output) { Emfsvg.from_bytes(bytes) }

  it "preserves EA102 definitions in their original groups and every drawing" do
    expect(Emf.parse(bytes).errors).to be_empty
    expect(output).to eq(fixture)
  end

  it "keeps native clipping and save scopes balanced through the final unused definitions" do
    stack = []
    clip = nil
    clipped_draws = 0
    records = Emf.parse(bytes).records.map(&:wire)
    records.each do |wire|
      case wire
      when Emf::Emr::Binary::Records::SaveDc then stack << clip
      when Emf::Emr::Binary::Records::RestoreDc
        expect(stack).not_to be_empty
        clip = stack.pop
      when Emf::Emr::Binary::Records::IntersectClipRect then clip = wire.rcl_clip.snapshot
      when Emf::Emr::Binary::Records::ExtSelectClipRgn
        expect([wire.cb_rgn_data.to_i, wire.dw_mode.to_i]).to eq([0, 5])
        clip = nil
      when Emf::Emr::Binary::Records::Polygon, Emf::Emr::Binary::Records::PolyPolygon,
           Emf::Emr::Binary::Records::FillPath, Emf::Emr::Binary::Records::StrokeAndFillPath
        clipped_draws += 1 if clip
      end
    end
    expect(stack).to be_empty
    expect(clip).to be_nil
    expect(clipped_draws).to eq(1)
    expect(output.scan("<clipPath ").size).to eq(5)
  end

  let(:definition) do
    '<defs><clipPath id="clip-16807"><path d="M 0.0000,0.0000 L 8.0000,0.0000 ' \
      'L 8.0000,9.0000 L 0.0000,9.0000 L 0.0000,0.0000 Z Z" /></clipPath></defs>'
  end
  let(:identity) { "matrix(1.0000 0.0000 0.0000 1.0000 0.0000 0.0000)" }
  let(:scaled) { "matrix(2.0000 0.0000 0.0000 2.0000 0.0000 0.0000)" }
  let(:sibling_source) do
    <<~SVG
      <svg width="40" height="40"><g transform="translate(0,0)">
      <g transform="#{identity}">#{definition}</g><g transform="#{scaled}">
      <path clip-path="url(#clip-16807)" d="M 1,1 L 2,1 L 2,2 Z" fill="#ff0000"/>
      </g><rect x="20" y="21" width="3" height="4"/></g></svg>
    SVG
  end

  [[:ordinary_transform, lambda { |svg|
    svg.sub('transform="matrix(1.0000 0.0000 0.0000 1.0000 0.0000 0.0000)"', 'transform="scale(1)"')
  }],
   [:ordinary_id, ->(svg) { svg.gsub("clip-16807", "custom") }],
   [:ordinary_rectangle, ->(svg) { svg.sub(" Z Z", " Z") }]].each do |name, change|
    it "retains ordinary per-drawing clipping for #{name}" do
      result = Emfsvg.from_bytes(Emfsvg.from_svg(change.call(sibling_source)))
      expect(result.index("<defs>")).to be > result.index(%(<g transform="#{scaled}">))
      expect(result.lines.grep(/<rect /).last).not_to include("clip-path")
      expect(result.scan("<clipPath ").size).to eq(1)
    end
  end

  it "does not carry a definition across an intervening drawing" do
    source = sibling_source.sub(%(</g><g transform="#{scaled}">),
                                %(</g><rect width="1" height="1"/><g transform="#{scaled}">))
    result = Emfsvg.from_bytes(Emfsvg.from_svg(source))
    expect(result.index("<defs>")).to be > result.index(%(<g transform="#{scaled}">))
    expect(result.lines.grep(/<rect /)).to all(satisfy { |line| !line.include?("clip-path") })
  end

  it "does not carry a definition shared by drawings in multiple groups" do
    source = sibling_source.sub("</g></svg>",
                                '<g><path clip-path="url(#clip-16807)" d="M 1,1 L 2,1 L 2,2 Z"/></g></g></svg>')
    result = Emfsvg.from_bytes(Emfsvg.from_svg(source))
    expect(result.index("<defs>")).to be > result.index(%(<g transform="#{scaled}">))
    expect(result.scan("<clipPath ").size).to eq(2)
  end

  it "keeps the ordinary clipping path after an earlier real clip mutation" do
    earlier = '<defs><clipPath id="other"><rect width="1" height="1"/></clipPath></defs>' \
              '<rect clip-path="url(#other)" width="1" height="1"/>'
    source = sibling_source.sub('<g transform="translate(0,0)">', %(<g transform="translate(0,0)">#{earlier}))
    emitted = Emfsvg.from_svg(source)
    result = Emfsvg.from_bytes(emitted)
    expect(result.rindex("<defs>")).to be > result.index(%(<g transform="#{scaled}">))
    expect(Emf.parse(emitted).records.map(&:wire).grep(Emf::Emr::Binary::Records::ExtSelectClipRgn)).to be_empty
    expect(result.lines.grep(/<rect /).last).not_to include("clip-path")
  end
end
