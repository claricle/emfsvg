# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Canonical circular arc translation" do
  let(:data) { "M 900.0000,1500.0000 M 1343.9340,1343.9340 A 150.0000,150.0000 0 0 0 1450.0000,1600.0000 " }

  let(:tag) do
    lambda do |data|
      "<path d=\"#{data}\" stroke=\"#7FFFC4\" stroke-width=\"50.0000\"  " \
        "stroke-linecap=\"square\"  stroke-linejoin=\"miter\"  stroke-miterlimit=\"8.0000\"  fill=\"none\" />"
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

  it "preserves the exact canonical circular arc rather than dropping A" do
    records, output = convert.call(tag.call(data))
    expect(output.lines.map(&:strip)).to include(tag.call(data))
    expect(records.grep(Emf::Emr::Binary::Records::Arc).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::ArcTo)).to be_empty
    expect(records.grep(Emf::Emr::Binary::Records::AngleArc)).to be_empty
  end

  it "uses a native nonconnecting arc and explicitly restores the endpoint current position" do
    records, output = convert.call("#{tag.call(data)}<path d=\"M 10 20 L 30 40\" fill=\"none\" stroke=\"red\"/>")
    index = records.index { |record| record.is_a?(Emf::Emr::Binary::Records::Arc) }
    move = records.fetch(index + 1)
    expect(move).to be_a(Emf::Emr::Binary::Records::MoveToEx)
    arc = records.fetch(index)
    expect(move.origin.snapshot).to eq(arc.ptl_end.snapshot)
    expect(output).to include("M 10.0000,20.0000 L 30.0000,40.0000 ")
    expect(records.grep(Emf::Emr::Binary::Records::LineTo).size).to eq(1)
  end

  it "preserves the major clockwise circular sweep" do
    major = data.sub("0 0 0 1450", "0 1 1 1450")
    records, output = convert.call(tag.call(major))
    expect(output.lines.map(&:strip)).to include(tag.call(major))
    expect(records.grep(Emf::Emr::Binary::Records::SetArcDirection).last.arc_direction.to_i).to eq(2)
    arc = records.grep(Emf::Emr::Binary::Records::Arc).first
    # In native screen coordinates the specified direction sweeps 225 degrees.
    center_x = (arc.rcl_box.left.to_f + arc.rcl_box.right.to_f) / 2
    center_y = (arc.rcl_box.top.to_f + arc.rcl_box.bottom.to_f) / 2
    start_angle = Math.atan2(arc.ptl_start.y.to_i - center_y, arc.ptl_start.x.to_i - center_x)
    end_angle = Math.atan2(arc.ptl_end.y.to_i - center_y, arc.ptl_end.x.to_i - center_x)
    expect((end_angle - start_angle) % (2 * Math::PI)).to be_within(0.001).of(5 * Math::PI / 4)
  end

  it "keeps derived bounds from overflowing the selected fixed scale" do
    overflow = "M 0.0001,0.0000 M 200000.0000,180000.0000 " \
               "A 20000.0000,20000.0000 0 0 0 180000.0000,200000.0000 "
    records, = convert.call(tag.call(overflow))
    expect(records.grep(Emf::Emr::Binary::Records::Arc)).to be_empty
  end

  it "does not infer native arc provenance from ordinary SVG spelling" do
    records, = convert.call(tag.call(data).sub("  stroke-linecap", " stroke-linecap"))
    expect(records.grep(Emf::Emr::Binary::Records::Arc)).to be_empty
  end

  it "leaves elliptical, mismatched flags and nonrecoverable radial geometry unchanged" do
    [data.sub("150.0000,150.0000", "150.0000,160.0000"),
     data.sub("0 0 0 1450", "0 0 1 1450"),
     data.sub("1343.9340,1343.9340", "1343.9350,1343.9340")].each do |unsupported|
      records, = convert.call(tag.call(unsupported))
      expect(records.grep(Emf::Emr::Binary::Records::Arc)).to be_empty
    end
  end
end
