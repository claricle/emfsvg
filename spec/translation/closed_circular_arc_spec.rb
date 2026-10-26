# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Canonical closed circular arc translation" do
  let(:chord) { "M 1750.0000,1450.0000 M 1943.9340,1343.9340 A 150.0000,150.0000 0 0 0 2050.0000,1600.0000 Z " }
  let(:pie) do
    "M 2050.0000,1600.0000 M 2243.9340,1343.9340 A 150.0000,150.0000 0 1 1 2350.0000,1600.0000 " \
      "L 2350.0000,1450.0000 Z "
  end
  let(:tag) do
    lambda do |data|
      "<path d=\"#{data}\" stroke=\"#7FFFC4\" stroke-width=\"50.0000\"  " \
        "stroke-linecap=\"square\"  stroke-linejoin=\"miter\"  stroke-miterlimit=\"8.0000\"  fill=\"#C47FFF\"  />"
    end
  end
  let(:convert) do
    lambda do |source|
      bytes = Emfsvg.from_svg(%(<svg width="3000" height="3000">#{source}</svg>))
      parsed = Emf.parse(bytes)
      expect(parsed.errors).to be_empty
      [parsed.records.map(&:wire), Emfsvg.from_bytes(bytes)]
    end
  end

  it "preserves the canonical Chord and clockwise Pie including their fill and closure" do
    records, output = convert.call(tag.call(chord) + tag.call(pie))
    expect(output.lines.map(&:strip)).to include(tag.call(chord), tag.call(pie))
    expect(records.grep(Emf::Emr::Binary::Records::Chord).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::Pie).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::Arc)).to be_empty
    expect(records.grep(Emf::Emr::Binary::Records::SetArcDirection).map { |r| r.arc_direction.to_i }).to eq([1, 2])
  end

  it "restores SVG Z current position explicitly without adding a connecting line" do
    records, output = convert.call("#{tag.call(chord)}#{tag.call(pie)}" \
                                   '<path d="M 10 20 L 30 40" fill="none" stroke="red"/>')
    [Emf::Emr::Binary::Records::Chord, Emf::Emr::Binary::Records::Pie].zip([1943.934, 2243.934]).each do |kind, x|
      index = records.index { |record| record.is_a?(kind) }
      move = records.fetch(index + 1)
      expect(move).to be_a(Emf::Emr::Binary::Records::MoveToEx)
      # Fixed-point translation retains the fractional SVG subpath start.
      expect(move.origin.x.to_i).to eq((x * 10_000).round)
      expect(move.origin.y.to_i).to eq(13_439_340)
    end
    expect(records.grep(Emf::Emr::Binary::Records::LineTo).size).to eq(1)
    expect(output).to include("M 10.0000,20.0000 L 30.0000,40.0000 ")
  end

  it "does not infer a native record from noncanonical spelling or a different Pie center" do
    [tag.call(chord).sub("  stroke-linecap", " stroke-linecap"),
     tag.call(pie.sub("L 2350.0000,1450.0000", "L 2351.0000,1450.0000")),
     tag.call(chord).sub('fill="#C47FFF"', 'fill="none"'),
     tag.call(chord.sub("150.0000,150.0000", "150.0000,160.0000"))].each do |source|
      records, = convert.call(source)
      expect(records.grep(Emf::Emr::Binary::Records::Chord)).to be_empty
      expect(records.grep(Emf::Emr::Binary::Records::Pie)).to be_empty
    end
  end
end
