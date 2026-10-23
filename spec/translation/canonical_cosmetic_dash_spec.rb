# frozen_string_literal: true

require "spec_helper"
require "leptris"

RSpec.describe "canonical cosmetic dash recovery" do
  include Emfsvg::SpecSupport::CanonicalCosmeticDashConversion

  let(:source_paths) { File.readlines("spec/fixtures/emfsvg_golden/test-039.svg")[82, 4].map(&:strip) }

  [[0, 5, 1], [1, 6, 2], [2, 7, 3], [3, 8, 4]].each do |index, width, style|
    2.times do |fixed_index|
      fixed = fixed_index == 1
      it "recovers cosmetic style #{style} with #{fixed ? 'fixed' : 'identity'} scaling" do
        path = source_paths.fetch(index)
        pens, output = dash_conversion(path, fixed: fixed)

        expect(pens.first.width.x.to_i).to eq(width * (fixed ? 10_000 : 1))
        expect(pens.first.pen_style.to_i).to eq(style)
        expect(output).to include(path) unless fixed
        if fixed
          following = Leptris::XML.parse(output).xpath("//*[local-name()='path']").last
          expect(pens.last.width.x.to_i).to eq(1)
          expect(pens.last.pen_style.to_i).to eq(0)
          expect([following["d"], following["stroke"], following["stroke-width"]])
            .to eq(["M 1.0000,2.0000 L 3.0000,4.0000 ", "#0000FF", "1px"])
        end
      end
    end
  end

  it "keeps near-canonical source spacing on the ordinary geometric path" do
    path = source_paths.first.sub("  stroke-linecap", " stroke-linecap")
    pens, output = dash_conversion(path)

    expect(pens.first.width.x.to_i).to eq(1)
    expect(pens.first.pen_style.to_i).to eq(0x10001)
    expect(output).to include('stroke-dasharray="5.0000,5.0000"')
  end

  it "keeps ordinary SVG with the same style values geometric" do
    path = '<path d="M 300,3700 L 500,3900 L 300,4100" stroke="#FF00FF" stroke-width="1.0000" ' \
           'stroke-dasharray="25.0000,25.0000" stroke-linecap="round" stroke-linejoin="round" fill="none"/>'
    pens, = dash_conversion(path)

    expect(pens.first.width.x.to_i).to eq(1)
    expect(pens.first.pen_style.to_i).to eq(0x10001)
  end

  2.times do |order|
    it "keeps the shared parsed stroke cache unchanged in order #{order}" do
      canonical = source_paths.first
      ordinary = canonical.sub("  stroke-linecap", " stroke-linecap")
      paths = [canonical, ordinary]
      expected = [[5, 1], [1, 0x10001]]
      if order == 1
        paths.reverse!
        expected.reverse!
      end
      pens, = dash_conversion(paths.join)

      expect(pens.map { |pen| [pen.width.x.to_i, pen.pen_style.to_i] }).to eq(expected)
    end
  end

  it "rejects a noncanonical dash ratio" do
    path = source_paths.fetch(2).sub("7.0000,35.0000", "8.0000,35.0000")
    pens, = dash_conversion(path)

    expect(pens.first.width.x.to_i).to eq(1)
    expect(pens.first.pen_style.to_i).to eq(0x10001)
  end

  it "preserves canonical geometric widths" do
    path = source_paths.first.sub('stroke-width="1.0000"', 'stroke-width="5.0000"')
    pens, output = dash_conversion(path)

    expect(pens.first.width.x.to_i).to eq(5)
    expect(pens.first.pen_style.to_i).to eq(0x10001)
    expect(output).to include(path)
  end
end
