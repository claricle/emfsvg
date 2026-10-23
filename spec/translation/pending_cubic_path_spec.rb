# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Canonical pending cubic paths" do
  let(:data) { "M 1.0000,2.0000 L 3.0000,4.0000 C 5.0000,6.0000 7.0000,8.0000 9.0000,10.0000 " }
  let(:path) { %(<path d="#{data}" fill="none" stroke="none" />) }
  let(:source) { %(<svg width="40" height="40">#{path}</svg>) }
  let(:bytes) { Emfsvg.from_svg(source) }
  let(:wires) { Emf.parse(bytes).records.map(&:wire) }

  it "retains an unpainted cubic path for later clipping" do
    expect(Emf.parse(bytes).errors).to be_empty
    expect(wires.grep(Emf::Emr::Binary::Records::EndPath).size).to eq(1)
    expect(wires.grep(Emf::Emr::Binary::Records::StrokeAndFillPath)).to be_empty
    expect(wires.grep(Emf::Emr::Binary::Records::FillPath)).to be_empty
    expect(wires.grep(Emf::Emr::Binary::Records::StrokePath)).to be_empty
    expect(Emfsvg.from_bytes(bytes)).to include(path)
  end

  it "preserves ordinary invisible paths with different source spelling" do
    ordinary = Emf.parse(Emfsvg.from_svg(source.sub('stroke="none" />', 'stroke="none"/>'))).records.map(&:wire)
    expect(ordinary.grep(Emf::Emr::Binary::Records::StrokeAndFillPath).size).to eq(1)
  end
end
