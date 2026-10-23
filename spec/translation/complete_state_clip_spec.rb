# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Adjacent complete clipped drawings" do
  let(:body) do
    <<~SVG
      <path clip-path="url(#c)" d="M1,1 L9,1 L9,9 Z" stroke="#ff0000" fill="#00ff00"/>
      <text clip-path="url(#c)" x="10" y="20" font-size="12" fill="#ff00ff">one</text>
      <path clip-path="url(#c)" d="M20,20 L23,24" stroke="#0000ff" stroke-width="3" stroke-miterlimit="5" stroke-linejoin="miter" fill="none"/>
      <text clip-path="url(#c)" x="30" y="40" font-size="15" fill="#00ffff" text-anchor="end">two</text>
      <path d="M70,70 L75,70 L75,75 Z" stroke="#000000" fill="#ffffff"/>
    SVG
  end
  let(:svg) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
        <defs><clipPath id="c"><rect x="0" y="0" width="50" height="50"/></clipPath></defs>
        #{body}
      </svg>
    SVG
  end
  let(:bytes) { Emfsvg.from_svg(svg) }
  let(:wires) { Emf.parse(bytes).records.map(&:wire) }
  let(:output) { Emfsvg.from_bytes(bytes) }

  it "shares one native scope while preserving each draw's complete style and unclipped successor" do
    expect(wires.grep(Emf::Emr::Binary::Records::SaveDc).size).to eq(1)
    expect(wires.grep(Emf::Emr::Binary::Records::RestoreDc).map { |wire| wire.saved_dc.to_i }).to eq([-1])
    expect(output.scan("<clipPath ").size).to eq(1)
    expect(output).to include('stroke="#FF0000"', 'fill="#00FF00"', 'stroke="#0000FF"',
                              'stroke-width="3.0000"', 'stroke-miterlimit="5.0000"',
                              'fill="#FF00FF"', 'fill="#00FFFF"', 'font-size="12.0000"',
                              'font-size="15.0000"', 'text-anchor="end"', "one", "two")
    last = output.lines.find { |line| line.include?("70.0000,70.0000") }
    expect(last).to include('stroke="#000000"', 'fill="#FFFFFF"')
    expect(last).not_to include("clip-path")
  end

  it "has balanced popping saves with all four clipped draws followed by an unclipped draw" do
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
      when Emf::Emr::Binary::Records::Polygon, Emf::Emr::Binary::Records::Polyline,
           Emf::Emr::Binary::Records::LineTo, Emf::Emr::Binary::Records::ExtTextOutW
        draws << clip
      end
    end
    expect(stack).to be_empty
    expect(draws.size).to eq(5)
    expect(draws.first(4)).to all(be_truthy)
    expect(draws.last).to be_nil
  end

  context "with all supported primitive handlers" do
    let(:body) do
      <<~SVG
        <rect clip-path="url(#c)" x="1" y="2" width="3" height="4" fill="#ff0000"/>
        <ellipse clip-path="url(#c)" cx="10" cy="10" rx="3" ry="4" fill="#00ff00"/>
        <line clip-path="url(#c)" x1="20" y1="21" x2="22" y2="23" stroke="#0000ff"/>
        <polyline clip-path="url(#c)" points="30,31 32,33 34,35" stroke="#ff00ff" fill="none"/>
        <polygon clip-path="url(#c)" points="40,41 42,43 44,45" fill="#00ffff"/>
      SVG
    end

    it "retains absolute geometry and independent styles inside one scope" do
      expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(1)
      expect(output).to include('x="1.0000"', 'width="3.0000"', 'cx="10.0000"',
                                "20.0000,21.0000", "22.0000,23.0000", "30.0000,31.0000",
                                "40.0000,41.0000", "#FF0000", "#00FF00", "#0000FF", "#FF00FF", "#00FFFF")
    end
  end

  context "with a custom text handler" do
    let(:bytes) do
      registry = Emfsvg::Translation::HandlerRegistry.new
      registry.register(Emfsvg::Svg::Elements::Path, Emfsvg::Translation::Handlers::PathHandler)
      registry.register(Emfsvg::Svg::Elements::Text, Class.new(Emfsvg::Translation::Handlers::TextHandler))
      document = Emfsvg::Svg::Parser.call(svg)
      Emf.serialize(Emfsvg::Translation::EmfRenderer.call(document, registry: registry))
    end

    it "isolates unknown custom state" do
      expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(4)
      expect(wires.grep(Emf::Emr::Binary::Records::SaveDc).size).to eq(4)
    end
  end

  context "with transformed text" do
    let(:body) { super().sub('x="10"', 'transform="translate(2,3)" x="10"') }

    it "retains an isolated transform scope between the shape runs" do
      expect(wires.grep(Emf::Emr::Binary::Records::SaveDc).size).to eq(3)
      expect(wires.grep(Emf::Emr::Binary::Records::RestoreDc).size).to eq(3)
      expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(3)
    end
  end
end
