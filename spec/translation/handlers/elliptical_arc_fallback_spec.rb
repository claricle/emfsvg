# frozen_string_literal: true

require "spec_helper"
require "leptris"

RSpec.describe "SVG elliptical arc fallback" do
  include Emfsvg::SpecSupport::EllipticalArcFallback

  let(:flattener) { Emfsvg::Translation::Handlers::PathFlattener }

  it "preserves the unsupported test-156 elliptical curve as cubics" do
    data = "M 5267.9063,3340.8492 A 3504.4800,3984.4800 0 0 0 4932.0937,3340.8492 L 5100,5579.04 Z"
    commands = Emfsvg::Svg::PathData::Parser.parse(data)
    legacy_segments = PreviousFlattening::Translation::Handlers::PathFlattener.flatten(commands).first.segments
    segments = flattener.flatten(commands).first.segments

    expect(legacy_segments.map(&:first)).not_to include("C")
    expect(segments.map(&:first)).to include("C")
    expect(segments.last.first).to eq("Z")

    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
        <path d="#{data}" fill="none" stroke="#000"/>
      </svg>
    SVG
    output = Emfsvg.from_bytes(Emfsvg.from_svg(svg))
    expect(output).to include(" C ")
  end

  it "normalizes negative radii and honors rotation, relative endpoints, and sweep" do
    negative = flatten("M 10 20 a -15,-5 30 0 1 12,8").segments
    positive = flatten("M 10 20 a 15,5 30 0 1 12,8").segments
    segment = negative.find { |letter, _| letter == "C" }

    expect(segment).not_to be_nil
    expect(segment.last.last).to eq([22.0, 28.0])
    expect(segment.last.flatten.all?(&:finite?)).to be(true)
    expect(negative).to eq(positive)
  end

  it "uses quarter-ellipse control points and honors sweep and large-arc flags" do
    quarter = flatten("M 1 0 A 1 1 0 0 1 0 1").segments.find { |letter, _| letter == "C" }.last
    reverse_sweep = flatten("M 1 0 A 1 1 0 0 0 0 1").segments.find { |letter, _| letter == "C" }.last
    small = flatten("M 1 0 A 2 2 0 0 1 0 1").segments.count { |letter, _| letter == "C" }
    large = flatten("M 1 0 A 2 2 0 1 1 0 1").segments.count { |letter, _| letter == "C" }
    kappa = (4.0 / 3.0) * Math.tan(Math::PI / 8)

    expect(quarter).to eq([[1.0, kappa], [kappa, 1.0], [0.0, 1.0]])
    expect(reverse_sweep).not_to eq(quarter)
    expect(small).to eq(1)
    expect(large).to eq(4)
  end

  it "uses a line for a zero radius and emits no segment for coincident endpoints" do
    degenerate = flatten("M 1 2 A 0 5 0 0 1 8 9")
    coincident = flatten("M 1 2 A 5 5 0 0 1 1 2")

    expect(degenerate.segments.map(&:first)).to eq(%w[M L])
    expect(degenerate.segments.last.last).to eq([[8.0, 9.0]])
    expect(coincident.segments.map(&:first)).to eq(["M"])
  end
end
