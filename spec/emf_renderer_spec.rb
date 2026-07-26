# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::Translation::EmfRenderer do
  let(:document) { Emfsvg::Svg::Parser.call('<svg width="100" height="80"></svg>') }

  describe ".call" do
    it "builds an Emf::Model::Metafile with header + EOF" do
      metafile = described_class.call(document)
      expect(metafile).to be_a(Emf::Model::Metafile)
      expect(metafile.format).to eq(:emf)
      expect(metafile.records.size).to eq(1)
      expect(metafile.records.first.wire).to be_a(Emf::Emr::Binary::Records::Eof)
    end

    it "computes header bounds from document viewport" do
      metafile = described_class.call(document)
      expect(metafile.header.bounds.left).to eq(0)
      expect(metafile.header.bounds.top).to eq(0)
      expect(metafile.header.bounds.right).to eq(100)
      expect(metafile.header.bounds.bottom).to eq(80)
    end

    it "sets n_records to header + body count" do
      metafile = described_class.call(document)
      expect(metafile.header.n_records).to eq(2)
    end
  end
end

RSpec.describe Emfsvg, "#from_svg" do
  it "produces EMF bytes that Emf.parse can re-read" do
    bytes = Emfsvg.from_svg('<svg width="100" height="50"></svg>')
    # EMF header: iType=1 at offset 0, " EMF" signature at offset 40.
    expect(bytes.bytes[0, 4]).to eq([1, 0, 0, 0])
    expect(bytes.bytes[40, 4]).to eq([0x20, 0x45, 0x4D, 0x46])

    metafile = Emf.parse(bytes)
    expect(metafile.format).to eq(:emf)
    expect(metafile.records.size).to eq(1)
  end

  it "produces EMF bytes that emfsvg renders back to SVG" do
    bytes = Emfsvg.from_svg('<svg width="200" height="120"></svg>')
    svg = Emfsvg.from_bytes(bytes)
    expect(svg).to start_with("<?xml")
    expect(svg).to include("<svg")
    expect(svg).to include('width="200.0000"')
    expect(svg).to include('height="120.0000"')
    expect(svg).to include("</svg>")
  end
end
