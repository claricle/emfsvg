# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Canonical clip intervals" do
  %w[001 002 003 004].each do |number|
    it "preserves every path's original clip and style in test-#{number}" do
      source = File.binread(File.expand_path("../fixtures/emfsvg_golden/test-#{number}.svg", __dir__))
      output = Emfsvg.from_bytes(Emfsvg.from_svg(source))
      expect(output.lines.grep(/\A<path /)).to eq(source.lines.grep(/\A<path /))
    end
  end

  %w[031 056 060].each do |number|
    it "preserves every source byte including nested clips in test-#{number}" do
      source = File.binread(File.expand_path("../fixtures/emfsvg_golden/test-#{number}.svg", __dir__))
      bytes = Emfsvg.from_svg(source)
      expect(Emf.parse(bytes).errors).to be_empty
      expect(Emfsvg.from_bytes(bytes).b).to eq(source)
    end
  end

  let(:source) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
      <g transform="translate(0.0000, 0.0000)">
      <defs><clipPath id="clip-16807"><path d="M 0.0000,0.0000 L 90.0000,0.0000 L 90.0000,90.0000 L 0.0000,90.0000 L 0.0000,0.0000 Z Z" /></clipPath></defs>
      <path clip-path="url(#clip-16807)" d="M 1,1 L 2,2" stroke="#ff0000" fill="none"/>
      <defs><clipPath id="clip-282475249"><path d="M 10.0000,10.0000 L 20.0000,10.0000 L 20.0000,20.0000 L 10.0000,20.0000 L 10.0000,10.0000 Z Z" /></clipPath></defs>
      <path clip-path="url(#clip-282475249)" d="M 11,11 L 12,12" stroke="#00ff00" fill="none"/>
      <path clip-path="url(#clip-16807)" d="M 3,3 L 4,4" stroke="#0000ff" fill="none"/>
      <path d="M 95,95 L 99,99" stroke="#000000" fill="none"/>
      </g></svg>
    SVG
  end
  let(:bytes) { Emfsvg.from_svg(source) }
  let(:wires) { Emf.parse(bytes).records.map(&:wire) }

  it "pops balanced native scopes and leaves the successor unclipped" do
    stack = []
    clip = nil
    draws = []
    wires.each do |wire|
      case wire
      when Emf::Emr::Binary::Records::SaveDc then stack << clip
      when Emf::Emr::Binary::Records::RestoreDc
        expect(wire.saved_dc.to_i).to eq(-1)
        expect(stack).not_to be_empty
        clip = stack.pop
      when Emf::Emr::Binary::Records::IntersectClipRect then clip = wire.rcl_clip.snapshot
      when Emf::Emr::Binary::Records::ExtSelectClipRgn
        expect(stack).to be_empty
        expect([wire.cb_rgn_data.to_i, wire.dw_mode.to_i]).to eq([0, 5])
        clip = nil
      when Emf::Emr::Binary::Records::LineTo then draws << clip
      end
    end
    expect(stack).to be_empty
    expect(clip).to be_nil
    expect(draws).to eq([
                          { left: 0, top: 0, right: 90, bottom: 90 },
                          { left: 10, top: 10, right: 20, bottom: 20 },
                          { left: 0, top: 0, right: 90, bottom: 90 }, nil
                        ])
    output = Emfsvg.from_bytes(bytes)
    expect(output.scan("<clipPath ").size).to eq(2)
    expect(output.lines.grep(/\A<path /).last).not_to include("clip-path")
  end

  context "with crossing clip lifetimes" do
    let(:source) do
      super().sub('<path d="M 95,95', <<~SVG.chomp)
        <path clip-path="url(#clip-282475249)" d="M 13,13 L 14,14" stroke="#00ff00" fill="none"/>
        <path d="M 95,95
      SVG
    end

    it "does not cross native scopes or leak a clip into the successor" do
      expect(wires.grep(Emf::Emr::Binary::Records::SaveDc).size)
        .to eq(wires.grep(Emf::Emr::Binary::Records::RestoreDc).size)
      expect(Emfsvg.from_bytes(bytes).lines.grep(/\A<path /).last).not_to include("clip-path")
    end
  end

  context "with ordinary clip identifiers" do
    let(:source) { super().gsub("clip-16807", "outer").gsub("clip-282475249", "inner") }

    it "keeps separate conservative scopes and every draw's own clip" do
      expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(3)
      expect(wires.grep(Emf::Emr::Binary::Records::ExtSelectClipRgn)).to be_empty
      expect(Emfsvg.from_bytes(bytes).lines.grep(/\A<path /).last).not_to include("clip-path")
    end
  end

  context "with a clip extending outside the enclosing rectangle" do
    let(:source) { super().gsub("20.0000", "120.0000") }

    it "keeps the larger region independent of the outer clip" do
      expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(3)
      expect(wires.grep(Emf::Emr::Binary::Records::ExtSelectClipRgn)).to be_empty
      expect(Emfsvg.from_bytes(bytes)).to include("L 120.0000,10.0000 L 120.0000,120.0000")
    end
  end

  context "with ordinary rectangle spelling" do
    let(:source) { super().gsub('Z Z" />', 'Z Z"/>') }

    it "keeps independently restored clips without a canonical interval" do
      expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(3)
      expect(wires.grep(Emf::Emr::Binary::Records::ExtSelectClipRgn)).to be_empty
    end
  end

  context "with a custom path handler" do
    let(:bytes) do
      registry = Emfsvg::Translation::HandlerRegistry.new
      registry.register(Emfsvg::Svg::Elements::Path, Class.new(Emfsvg::Translation::Handlers::PathHandler))
      registry.register(Emfsvg::Svg::Elements::Defs, Emfsvg::Translation::Handlers::DefsHandler)
      document = Emfsvg::Svg::Parser.call(source)
      Emf.serialize(Emfsvg::Translation::EmfRenderer.call(document, registry: registry))
    end

    it "isolates custom drawing state even with canonical clip spelling" do
      expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(3)
      expect(wires.grep(Emf::Emr::Binary::Records::ExtSelectClipRgn)).to be_empty
    end
  end
end
