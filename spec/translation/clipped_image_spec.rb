# frozen_string_literal: true

require "spec_helper"
require "libpng"
require "base64"

RSpec.describe "Clipped embedded images" do
  let(:pixels) { [255, 0, 0, 255, 0, 255, 0, 255].pack("C*") }
  let(:png) { Libpng.encode(2, 1, pixels, pixel_format: "RGBA") }
  let(:href) { "data:image/png;base64,#{Base64.strict_encode64(png)}" }
  let(:clip) { 'clip-path="url(#window)"' }
  let(:svg) do
    <<~SVG
      <svg width="40" height="30">
      <defs><clipPath id="window"><rect x="4" y="5" width="6" height="7"/></clipPath></defs>
      <image x="2" y="3" width="20" height="10" #{clip} href="#{href}"/>
      <rect x="25" y="20" width="3" height="4" fill="#112233"/>
      </svg>
    SVG
  end
  let(:bytes) { Emfsvg.from_svg(svg) }
  let(:parsed) { Emf.parse(bytes) }
  let(:records) { parsed.records.map(&:wire) }
  let(:output) { Emfsvg.from_bytes(bytes) }

  it "scopes the image clip without clipping the following shape" do
    expect(parsed.errors).to be_empty
    clip_record = records.grep(Emf::Emr::Binary::Records::IntersectClipRect).last
    expect(clip_record).not_to be_nil
    expect(clip_record.rcl_clip.snapshot.values).to eq([4, 5, 10, 12])
    image_index = records.index { |record| record.is_a?(Emf::Emr::Binary::Records::StretchDIBits) }
    restore_index = records.index { |record| record.is_a?(Emf::Emr::Binary::Records::RestoreDc) }
    expect(records.index(clip_record)).to be < image_index
    expect(restore_index).to be > image_index
    expect(output.lines.grep(/<image /).first).to include('clip-path="url(#clip-')
    expect(output.lines.grep(/#112233/).first).not_to include("clip-path")
  end

  it "preserves embedded pixels and destination geometry" do
    image = records.grep(Emf::Emr::Binary::Records::StretchDIBits).first
    expect([image.x_dest.to_i, image.y_dest.to_i, image.cx_dest.to_i, image.cy_dest.to_i]).to eq([2, 3, 20, 10])
    expect(image.trailing.to_s.byteslice(40, png.bytesize)).to eq(png)
    rendered = Base64.strict_decode64(output[%r{data:image/png;base64,([^"]+)}, 1])
    expect(Libpng.decode(rendered, pixel_format: "RGBA").pixels).to eq(pixels)
    expect(output.lines.grep(/<image /).first).to include('width="20.0000" height="10.0000"')
  end

  it "matches the pinned C renderer for the same emitted clipped wire", :live_reference do
    require "tempfile"
    Tempfile.create(["clipped-image", ".emf"]) do |file|
      file.binmode
      file.write(bytes)
      file.flush
      expect(Emfsvg::Compat.generate_reference(file.path)).to eq(output)
    end
  end

  context "without a clip reference" do
    let(:clip) { "" }

    it "does not introduce a clipping scope" do
      expect(records.grep(Emf::Emr::Binary::Records::IntersectClipRect)).to be_empty
      expect(records.grep(Emf::Emr::Binary::Records::SaveDc)).to be_empty
      expect(output.lines.grep(/<image /).first).not_to include("clip-path")
    end
  end
end
