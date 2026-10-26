# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Mapped canonical Pie translation" do
  %w[156 157 158 159].each do |id|
    it "preserves every frozen byte and native Pie in test-#{id}" do
      source = Emfsvg::SpecSupport::FixturePath.read_fixture("emfsvg_golden", "test-#{id}.svg")
      bytes = Emfsvg.from_svg(source)
      parsed = Emf.parse(bytes)
      expect(parsed.errors).to be_empty
      pies = parsed.records.map(&:wire).grep(Emf::Emr::Binary::Records::Pie)
      expect(pies.size).to eq(source.scan(/ A [^"<>]* L [^"<>]*Z /).size)
      expect(Emfsvg.from_bytes(bytes).b).to eq(source)
    end
  end

  it "restores the viewport origin before a subsequent ordinary line" do
    source = Emfsvg::SpecSupport::FixturePath.read_fixture("emfsvg_golden", "test-156.svg")
    source = source.sub(%r{</g>\s*</svg>},
                        '<line x1="10" y1="20" x2="30" y2="40" stroke="red"/></g></svg>')
    output = Emfsvg.from_bytes(Emfsvg.from_svg(source))
    expect(output).to include("M 10.0000,20.0000 L 30.0000,40.0000 ")
  end

  it "rejects a radius pair that cannot share an integer mapping origin" do
    commands = Emfsvg::Svg::PathData::Parser.parse(
      "M 8940,5580 M 5267.9063,3340.8492 A 3504.48,3984.49 0 0 0 4932.0937,3340.8492 L 5100,5579.04 Z"
    )
    inferred = Emfsvg::Translation::Handlers::MappedPie.from_commands(
      commands, scaler: Emfsvg::Translation::Scaler::Fixed.new
    )
    expect(inferred).to be_nil
  end
end
