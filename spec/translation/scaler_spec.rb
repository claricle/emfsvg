# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::Translation::Scaler::Identity do
  it "truncates decimal to int" do
    expect(described_class.new.to_int(3.7)).to eq(3)
    expect(described_class.new.to_int(-2.3)).to eq(-2)
  end

  it "passes integers unchanged" do
    expect(described_class.new.to_int(42)).to eq(42)
  end

  it "has factor 1" do
    expect(described_class.new.factor).to eq(1)
  end

  it "is not scaled" do
    expect(described_class.new).not_to be_scaled
  end
end

RSpec.describe Emfsvg::Translation::Scaler::Fixed do
  it "multiplies by factor (default 10000)" do
    expect(described_class.new.to_int(1.5)).to eq(15_000)
    expect(described_class.new.to_int(0.0001)).to eq(1)
  end

  it "rounds to nearest integer" do
    expect(described_class.new.to_int(1.23456)).to eq(12_346)
  end

  it "has factor 10000 by default" do
    expect(described_class.new.factor).to eq(10_000)
  end

  it "is scaled" do
    expect(described_class.new).to be_scaled
  end

  it "detects unsafe values that would overflow int32" do
    scaler = described_class.new
    expect(scaler.unsafe?(300_000)).to be true
    expect(scaler.unsafe?(100_000)).to be false
  end

  it "checks rounded int32 limits using the chosen factor" do
    scaler = described_class.new(2)
    expect(scaler.unsafe?(1_073_741_823.5)).to be false
    expect(scaler.unsafe?(1_073_741_824)).to be true
    expect(scaler.unsafe?(-1_073_741_824)).to be false
    expect(scaler.unsafe?(Float::INFINITY)).to be true
    expect { scaler.to_int(1_073_741_824) }.to raise_error(described_class::Overflow)
  end
end

RSpec.describe "SVG coordinate scaling" do
  def translated_svg(content)
    Emfsvg.from_svg(%(<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">#{content}</svg>))
  end

  it "preserves four decimal places through serialized EMF" do
    bytes = translated_svg('<rect x="1.2345" y="2.3456" width="10.1234" height="20.5678"/>')
    parsed = Emf.parse(bytes)

    expect(parsed.errors).to be_empty
    expect(Emfsvg.from_bytes(bytes)).to include('x="1.2345" y="2.3456" width="10.1234" height="20.5678"')
  end

  it "keeps integer coordinates in the unscaled map mode" do
    bytes = translated_svg('<rect x="1" y="2" width="10" height="20"/>')
    records = Emf.parse(bytes).records.map(&:wire)

    expect(records.grep(Emf::Emr::Binary::Records::SetMapMode)).to be_empty
    expect(Emfsvg.from_bytes(bytes)).to include('x="1.0000" y="2.0000" width="10.0000" height="20.0000"')
  end

  it "falls back before a derived rectangle bound overflows int32" do
    bytes = translated_svg('<rect x="200000.25" y="2" width="20000" height="20"/>')
    parsed = Emf.parse(bytes)

    expect(parsed.errors).to be_empty
    expect(parsed.records.map(&:wire).grep(Emf::Emr::Binary::Records::SetMapMode)).to be_empty
    expect(Emfsvg.from_bytes(bytes)).to include('x="200000.0000"')
  end

  it "rebuilds records without overflow when relative path points exceed the input range" do
    bytes = translated_svg('<rect x="1.25" y="2" width="3" height="4"/><path d="M 200000.25,0 l 20000,0"/>')
    parsed = Emf.parse(bytes)

    expect(parsed.errors).to be_empty
    expect(parsed.records.map(&:wire).grep(Emf::Emr::Binary::Records::SetMapMode)).to be_empty
    output = Emfsvg.from_bytes(bytes)
    expect(output.scan("<rect ").size).to eq(1)
    expect(output.scan("<path ").size).to eq(1)
    expect(output).to include("220000.0000,0.0000")
  end

  it "retains scaled clip, path and text records through serialization" do
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
        <defs><clipPath id="clip"><rect x="1.2345" y="2.3456" width="50" height="50"/></clipPath></defs>
        <path clip-path="url(#clip)" d="M 3.1234,4.5678 L 10.9876,11.5432" stroke="#000000"/>
        <text x="5.1234" y="25.6789" font-size="10.2340">decimal</text>
      </svg>
    SVG
    model = Emfsvg::Translation::EmfRenderer.call(Emfsvg::Svg::Parser.call(svg))
    bytes = Emf.serialize(model)
    parsed = Emf.parse(bytes)

    expect(parsed.errors).to be_empty
    expect(parsed.records.map { |record| record.wire.i_type }).to eq(model.records.map { |record| record.wire.i_type })
    output = Emfsvg.from_bytes(bytes)
    expect(output).to include("1.2345,2.3456", "3.1234,4.5678", "10.9876,11.5432", "<![CDATA[decimal]]>")
    expect(output).to include('x="5.1234" y="25.6789" font-size="10.2340"')
  end
end
