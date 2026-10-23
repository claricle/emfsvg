# frozen_string_literal: true

require "spec_helper"
require "libpng"
require "base64"

RSpec.describe "Canonical pending clip selections" do
  let(:geometry) { "M 0.0000,0.0000 L 0.0000,0.0000 L 0.0000,50.0000 L 90.0000,50.0000 L 90.0000,0.0000 " }
  let(:source) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
      <g transform="translate(0.0000, 0.0000)">
      <path d="#{geometry}" fill="none" stroke="none" />
      <defs><clipPath id="clip-16807"><path d="#{geometry}Z" /></clipPath></defs>
      <path d="M 1,1 L 2,2" stroke="#000000" fill="none"/>
      </g></svg>
    SVG
  end
  let(:bytes) { Emfsvg.from_svg(source) }
  let(:wires) { Emf.parse(bytes).records.map(&:wire) }

  it "preserves an unused selected path definition without clipping its successor" do
    output = Emfsvg.from_bytes(bytes)
    expect(output.lines.grep(/\A<defs>/)).to eq(source.lines.grep(/\A<defs>/))
    expect(wires.grep(Emf::Emr::Binary::Records::SelectClipPath).size).to eq(1)
    selection = wires.index { |wire| wire.is_a?(Emf::Emr::Binary::Records::SelectClipPath) }
    reset = wires[selection + 1]
    expect(reset).to be_a(Emf::Emr::Binary::Records::ExtSelectClipRgn)
    expect([reset.cb_rgn_data.to_i, reset.dw_mode.to_i]).to eq([0, 5])
    expect(output.lines.grep(/\A<path /).last).not_to include("clip-path")
    expect(Emf.parse(bytes).errors).to be_empty
  end

  it "preserves all unused selected definitions from test-186" do
    original = File.binread(File.expand_path("../fixtures/emfsvg_golden/test-186.svg", __dir__))
    output = Emfsvg.from_bytes(Emfsvg.from_svg(original))
    expect(output.lines.grep(/\A<defs>/)).to eq(original.lines.grep(/\A<defs>/))
  end

  context "with canonical cubic clip geometry" do
    let(:geometry) { "M 0.0000,0.0000 C 1.0000,2.0000 3.0000,4.0000 5.0000,6.0000 " }
    let(:clip) do
      document = Emfsvg::Svg::Parser.call(source)
      Emfsvg::Svg::ClipPathRegistry.from_document(document).lookup("url(#clip-16807)")
    end

    it "retains exact cubic geometry as a native selection candidate" do
      expect(clip.selected_path_data).to eq(geometry)
    end

    context "with ordinary clip path spelling" do
      let(:source) { super().sub('Z" />', 'Z"/>') }

      it "does not infer a native selection candidate" do
        expect(clip.selected_path_data).to be_nil
      end
    end
  end

  context "with adjacent images using the selected path" do
    let(:png) { Libpng.encode(2, 1, [255, 0, 0, 255, 0, 255, 0, 255].pack("C*"), pixel_format: "RGBA") }
    let(:image) do
      <<~SVG
        <image x="1" y="2" width="20" height="10" clip-path="url(#clip-16807)" href="data:image/png;base64,#{Base64.strict_encode64(png)}"/>
      SVG
    end
    let(:source) { super().sub("</clipPath></defs>\n", "</clipPath></defs>\n#{image}#{image}") }

    it "selects once and restores the empty clip before the successor" do
      output = Emfsvg.from_bytes(bytes)
      expect(wires.grep(Emf::Emr::Binary::Records::SelectClipPath).size).to eq(1)
      expect(output.lines.grep(/\A<defs>/)).to eq(source.lines.grep(/\A<defs>/))
      expect(output.lines.grep(/\A<image /).size).to eq(2)
      expect(output.lines.grep(/\A<image /)).to all(include('clip-path="url(#clip-16807)"'))
      expect(output.lines.grep(/\A<path /).last).not_to include("clip-path")
      expect(wires.grep(Emf::Emr::Binary::Records::SaveDc).size)
        .to eq(wires.grep(Emf::Emr::Binary::Records::RestoreDc).size)
      expect(Emf.parse(bytes).errors).to be_empty
    end

    context "when another use follows an unrelated drawing" do
      let(:source) { super().sub("</g></svg>", "#{image}</g></svg>") }

      it "does not extend the native selection across the unrelated drawing" do
        expect(wires.grep(Emf::Emr::Binary::Records::SelectClipPath)).to be_empty
      end
    end
  end

  context "with an ordinary resource identifier" do
    let(:source) { super().gsub("clip-16807", "ordinary") }

    it "does not infer native selection" do
      expect(wires.grep(Emf::Emr::Binary::Records::SelectClipPath)).to be_empty
    end
  end

  context "with different pending geometry" do
    let(:source) { super().sub('d="M 0.0000,0.0000', 'd="M 1.0000,0.0000') }

    it "does not select an unrelated path" do
      expect(wires.grep(Emf::Emr::Binary::Records::SelectClipPath)).to be_empty
    end
  end

  context "with ordinary pending path spelling" do
    let(:source) { super().sub('fill="none" stroke="none" />', 'fill="none" stroke="none"/>') }

    it "does not infer native selection" do
      expect(wires.grep(Emf::Emr::Binary::Records::SelectClipPath)).to be_empty
    end
  end
end
