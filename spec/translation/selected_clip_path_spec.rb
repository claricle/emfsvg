# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Canonical selected path clips" do
  let(:fixture) { File.read(File.expand_path("../fixtures/emfsvg_golden/test-182.svg", __dir__)) }
  let(:bytes) { Emfsvg.from_svg(fixture) }
  let(:records) { Emf.parse(bytes).records.map(&:wire) }

  it "preserves test-182 clipping corner order, implicit closure, and filled curves" do
    expect(Emf.parse(bytes).errors).to be_empty
    expect(Emfsvg.from_bytes(bytes)).to eq(fixture)
  end

  it "selects three native paths within balanced group scopes" do
    stack = []
    selected = false
    clipped_draws = 0
    records.each do |wire|
      case wire
      when Emf::Emr::Binary::Records::SaveDc then stack << selected
      when Emf::Emr::Binary::Records::RestoreDc then selected = stack.pop
      when Emf::Emr::Binary::Records::SelectClipPath
        expect(wire.region_mode.to_i).to eq(5)
        selected = true
      when Emf::Emr::Binary::Records::Polygon then clipped_draws += 1 if selected
      end
    end
    expect(stack).to be_empty
    expect(selected).to be(false)
    expect(clipped_draws).to eq(7)
    expect(records.grep(Emf::Emr::Binary::Records::SelectClipPath).size).to eq(3)
    expect(records.grep(Emf::Emr::Binary::Records::FillPath).size).to eq(13)
  end

  [[:transform, ->(svg) { svg.gsub("matrix(1.0000 0.0000 0.0000 1.0000 0.0000 0.0000)", "scale(1)") }],
   [:path_spelling, ->(svg) { svg.gsub('fill="none" stroke="none" />', 'stroke="none" fill="none" />') }],
   [:clip_spelling, ->(svg) { svg.gsub('Z" /></clipPath>', 'Z"/></clipPath>') }]].each do |name, change|
    it "retains ordinary bounds clipping for #{name}" do
      emitted = Emfsvg.from_svg(change.call(fixture))
      ordinary = Emf.parse(emitted).records.map(&:wire)
      expect(ordinary.grep(Emf::Emr::Binary::Records::SelectClipPath)).to be_empty
      expect(ordinary.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to be >= 3
    end
  end

  it "does not extend selected clipping onto an unreferenced trailing drawing" do
    source = fixture.sub('clip-path="url(#clip-470211272)"', 'data-clip="url(#clip-470211272)"')
    emitted = Emfsvg.from_svg(source)
    selections = Emf.parse(emitted).records.map(&:wire).grep(Emf::Emr::Binary::Records::SelectClipPath)
    expect(selections.size).to eq(2)
    expect(Emfsvg.from_bytes(emitted).lines.grep(/#5D5D5D/).first).not_to include("clip-path")
  end

  it "requires identical pending and selected path geometry" do
    source = fixture.sub('L 85.0000,85.0000 Z" /></clipPath>', 'L 84.0000,85.0000 Z" /></clipPath>')
    emitted = Emfsvg.from_svg(source)
    selections = Emf.parse(emitted).records.map(&:wire).grep(Emf::Emr::Binary::Records::SelectClipPath)
    expect(selections.size).to eq(2)
  end

  it "keeps ordinary pure cubic paths on their existing PolyBezier strategy" do
    path = '<path d="M 1.0000,2.0000 C 3.0000,4.0000 5.0000,6.0000 7.0000,8.0000 " ' \
           'fill="#E96330" stroke="none" />'
    emitted = Emfsvg.from_svg(%(<svg width="20" height="20">#{path}</svg>))
    ordinary = Emf.parse(emitted).records.map(&:wire)
    expect(ordinary.grep(Emf::Emr::Binary::Records::FillPath)).to be_empty
    expect(ordinary.grep(Emf::Emr::Binary::Records::PolyBezier).size).to eq(1)
  end
end
