# frozen_string_literal: true

require "spec_helper"
require "leptris"

RSpec.describe "cosmetic dash round-trip parity" do
  include Emfsvg::SpecSupport::CosmeticDashParityHelpers

  it "keeps dotted cosmetic pixels in device units while scaling geometry" do
    bytes = Emfsvg.from_svg(ellipse_svg(width: "1px", dash: "1,1", coordinate: "10.25"))
    parsed = Emf.parse(bytes)
    expect(parsed.errors).to be_empty
    pen = parsed.records.map(&:wire).find { |wire| wire.is_a?(Emf::Emr::Binary::Records::CreatePen) }

    expect(pen.width.x.to_i).to eq(1)
    expect(pen.pen_style.to_i & 0x1000F).to eq(2)
    ellipse = rendered_ellipse(bytes)
    expect(%w[cx cy rx ry stroke-width stroke-dasharray].map { |key| ellipse[key] })
      .to eq(%w[10.2500 10.0000 5.0000 4.0000 1px 1.0000,1.0000])
  end

  it "preserves the standard dashed cosmetic pattern" do
    ellipse = rendered_ellipse(Emfsvg.from_svg(ellipse_svg(width: "1px", dash: "5,5")))

    expect(ellipse["stroke-width"]).to eq("1px")
    expect(ellipse["stroke-dasharray"]).to eq("5.0000,5.0000")
  end

  it "preserves ordinary unitless dotted strokes" do
    ellipse = rendered_ellipse(Emfsvg.from_svg(ellipse_svg(width: "1", dash: "1,1")))

    expect(ellipse["stroke-width"]).to eq("1.0000")
    expect(ellipse["stroke-dasharray"]).to eq("1.0000,1.0000")
  end

  it "preserves geometric pen widths and their standard dashed pattern" do
    bytes = Emfsvg.from_svg(ellipse_svg(width: "2", dash: "10,10"))
    parsed = Emf.parse(bytes)
    pen = parsed.records.map(&:wire).find { |wire| wire.is_a?(Emf::Emr::Binary::Records::CreatePen) }

    expect(pen.width.x.to_i).to eq(2)
    expect(pen.pen_style.to_i & 0x1000F).to eq(0x10001)
    ellipse = rendered_ellipse(bytes)
    expect(ellipse["stroke-width"]).to eq("2.0000")
    expect(ellipse["stroke-dasharray"]).to eq("10.0000,10.0000")
  end
end
