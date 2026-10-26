# frozen_string_literal: true

require "spec_helper"

RSpec.describe "canonical open paths with NULL-pen brush fallback" do
  let(:path) do
    '<path d="M 2.2500,3.5000 L 12.7500,13.2500 L 20.5000,4.2500 " ' \
      'stroke-width="1px" stroke="#9F002D" fill="none" />'
  end
  let(:svg) { %(<svg xmlns="http://www.w3.org/2000/svg" width="30" height="30">#{path}</svg>) }
  let(:bytes) { Emfsvg.from_svg(svg) }
  let(:parsed) { Emf.parse(bytes) }
  let(:records) { parsed.records.map(&:wire) }
  let(:pen) { records.grep(Emf::Emr::Binary::Records::CreatePen).first }
  let(:brush) { records.grep(Emf::Emr::Binary::Records::CreateBrushIndirect).first }

  it "preserves an independent solid brush for an unfilled Polyline" do
    expect(parsed.errors).to be_empty
    expect(pen.pen_style.to_i & 0xF).to eq(5)
    expect(brush.brush_style.to_i).to eq(0)
    expect(brush.color.to_binary_s).to eq(pen.color.to_binary_s)
    expect(records.grep(Emf::Emr::Binary::Records::Polyline).size).to eq(1)
    expect(Emfsvg.from_bytes(bytes)).to include(path)
  end

  context "with a two-point canonical path" do
    let(:path) { super().sub(" L 20.5000,4.2500", "") }

    it "preserves Polyline spacing instead of LineTo spacing" do
      expect(parsed.errors).to be_empty
      expect(records.grep(Emf::Emr::Binary::Records::Polyline).size).to eq(1)
      expect(records.grep(Emf::Emr::Binary::Records::LineTo)).to be_empty
      expect(Emfsvg.from_bytes(bytes)).to include(path)
    end
  end

  [
    ['stroke-width="1px" stroke="#9F002D"', 'stroke="#9F002D" stroke-width="1px"'],
    ["M 2.2500,3.5000", "M 2.25,3.5"],
    ['fill="none" />', 'fill="none"/>'],
    ['fill="none" />', 'stroke-linecap="butt" fill="none" />']
  ].each do |original, replacement|
    context "with ordinary SVG spelling #{replacement.inspect}" do
      let(:path) { super().sub(original, replacement) }

      it "keeps a real cosmetic pen and a NULL brush" do
        expect(parsed.errors).to be_empty
        expect(pen.pen_style.to_i & 0xF).to eq(0)
        expect(brush.brush_style.to_i).to eq(1)
        expect(Emfsvg.from_bytes(bytes)).to include('stroke="#9F002D" stroke-width="1px"')
      end
    end
  end

  context "with an ordinary geometric stroke" do
    let(:path) { super().sub('stroke-width="1px"', 'stroke-width="2"') }

    it "preserves the geometric width and NULL brush" do
      expect(pen.pen_style.to_i & 0x1000F).to eq(0x10000)
      expect(brush.brush_style.to_i).to eq(1)
      expect(Emfsvg.from_bytes(bytes)).to include('stroke-width="2.0000"')
    end
  end

  context "with a filled NULL-pen fallback" do
    let(:path) { super().sub('fill="none"', 'fill="#9F002D"') }

    it "preserves the existing NULL pen and solid brush behavior" do
      expect(pen.pen_style.to_i & 0xF).to eq(5)
      expect(brush.brush_style.to_i).to eq(0)
      expect(Emfsvg.from_bytes(bytes)).to include('stroke-width="1px" stroke="#9F002D"')
    end
  end
end
