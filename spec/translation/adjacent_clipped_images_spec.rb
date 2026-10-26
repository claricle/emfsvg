# frozen_string_literal: true

require "spec_helper"
require "libpng"
require "base64"

RSpec.describe "Adjacent clipped embedded images" do
  let(:red_png) { Libpng.encode(1, 1, [255, 0, 0, 255].pack("C*"), pixel_format: "RGBA") }
  let(:green_png) { Libpng.encode(1, 1, [0, 255, 0, 255].pack("C*"), pixel_format: "RGBA") }
  let(:red_href) { "data:image/png;base64,#{Base64.strict_encode64(red_png)}" }
  let(:green_href) { "data:image/png;base64,#{Base64.strict_encode64(green_png)}" }
  let(:svg) do
    <<~SVG
      <svg width="40" height="30">
      <defs><clipPath id="window"><rect x="4" y="5" width="6" height="7"/></clipPath></defs>
      <image x="2" y="3" width="20" height="10" clip-path="url(#window)" href="#{red_href}"/>
      <image x="12" y="13" width="5" height="6" clip-path="url(#window)" href="#{green_href}"/>
      </svg>
    SVG
  end
  let(:parsed) { Emf.parse(Emfsvg.from_svg(svg)) }
  let(:records) { parsed.records.map(&:wire) }
  let(:images) { records.grep(Emf::Emr::Binary::Records::StretchDIBits) }

  it "reuses one adjacent clip scope while preserving both image payloads and destinations" do
    expect(parsed.errors).to be_empty
    expect(records.grep(Emf::Emr::Binary::Records::SaveDc).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::RestoreDc).size).to eq(1)
    expect(images.map { |image| [image.x_dest.to_i, image.y_dest.to_i, image.cx_dest.to_i, image.cy_dest.to_i] })
      .to eq([[2, 3, 20, 10], [12, 13, 5, 6]])
    expect(images.map { |image| Libpng.decode(image.trailing.to_s.byteslice(40..), pixel_format: "RGBA").pixels.bytes })
      .to eq([[255, 0, 0, 255], [0, 255, 0, 255]])
  end
end
