# frozen_string_literal: true

require "spec_helper"

RSpec.describe "solid-fill BitBlt parity" do
  let(:path) do
    '<path style="fill:#12ab34" d="M -5.0000,7.0000 L 18.0000,7.0000 L 18.0000,20.0000 L -5.0000,20.0000 Z" />'
  end
  let(:svg) { %(<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">#{path}</svg>) }
  let(:bytes) { Emfsvg.from_svg(svg) }
  let(:records) { Emf.parse(bytes).records.map(&:wire) }

  it "preserves the fill spelling and rectangle through the public roundtrip" do
    bitblt = records.grep(Emf::Emr::Binary::Records::BitBlt).first

    expect(bitblt).not_to be_nil
    expect([bitblt.x_dest.to_i, bitblt.y_dest.to_i, bitblt.cx_dest.to_i, bitblt.cy_dest.to_i]).to eq([-5, 7, 23, 13])
    expect(bitblt.cb_bits_src.to_i).to eq(0)
    expect(bitblt.dw_rop.to_i).to eq(0x00F00021)
    expect(records.grep(Emf::Emr::Binary::Records::Polygon)).to be_empty
    expect(Emfsvg.from_bytes(bytes)).to include(path)
  end

  it "preserves every canonical test-068 solid-fill path" do
    canonical = %r{<path style="fill:#[0-9a-f]{6}"[^>]*/>}
    expected = File.read(File.expand_path("../fixtures/golden/test-068.svg", __dir__)).scan(canonical)
    input = %(<svg xmlns="http://www.w3.org/2000/svg" width="5000" height="3500">#{expected.join}</svg>)
    output = Emfsvg.from_bytes(Emfsvg.from_svg(input))

    expect(expected.size).to eq(227)
    expect(output.scan(canonical)).to eq(expected)
  end

  it "renders the emitted wire identically with the pinned C reference", :live_reference do
    require "tempfile"
    Tempfile.create(["bitblt-fill", ".emf"]) do |file|
      file.binmode
      file.write(bytes)
      file.flush

      expect(Emfsvg::Compat.generate_reference(file.path)).to eq(Emfsvg.from_bytes(bytes))
    end
  end

  context "with ordinary presentation attributes" do
    let(:path) do
      '<path d="M -5.0000,7.0000 L 18.0000,7.0000 L 18.0000,20.0000 L -5.0000,20.0000 Z" fill="#12ab34" />'
    end

    it "keeps Polygon selection and the explicit fill" do
      expect(records.grep(Emf::Emr::Binary::Records::BitBlt)).to be_empty
      expect(records.grep(Emf::Emr::Binary::Records::Polygon).size).to eq(1)
      expect(Emfsvg.from_bytes(bytes)).to include('fill="#12AB34"')
    end
  end

  context "with reordered canonical attributes" do
    let(:path) do
      '<path d="M -5.0000,7.0000 L 18.0000,7.0000 L 18.0000,20.0000 L -5.0000,20.0000 Z" style="fill:#12ab34" />'
    end

    it "keeps the existing ordinary SVG Polygon strategy" do
      expect(records.grep(Emf::Emr::Binary::Records::BitBlt)).to be_empty
      expect(records.grep(Emf::Emr::Binary::Records::Polygon).size).to eq(1)
    end
  end

  context "with nonrectangular geometry in the canonical spelling" do
    let(:path) { super().sub("L 18.0000,7.0000", "L 19.0000,7.0000") }

    it "keeps the polygon geometry" do
      expect(records.grep(Emf::Emr::Binary::Records::BitBlt)).to be_empty
      polygon = records.grep(Emf::Emr::Binary::Records::Polygon).first
      expect(polygon.aptl[1].x.to_i).to eq(19)
    end
  end
end
