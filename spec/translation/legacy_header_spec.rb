# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Legacy broken-Y header provenance" do
  include Emfsvg::SpecSupport::LegacyHeaderHelpers

  let(:legacy) { "translate(0.0000, 0.00 00)" }
  let(:golden) { File.expand_path("../fixtures/emfsvg_golden", __dir__) }

  %w[test-183 test-184 test-185].each do |name|
    it "#{name} round-trips with every byte equal" do
      expected = File.binread(File.join(golden, "#{name}.svg"))
      actual = Emfsvg.from_bytes(Emfsvg.from_svg(expected))
      expect(actual.b == expected).to be(true)
    end
  end

  it "builds canonical signed bounds for the exact legacy header" do
    expect(header_bounds(svg("8002.0000", "4502.0000", legacy))).to eq([-1, -1, 8000, 4500])
  end

  it "keeps ordinary zero translate bounds unchanged" do
    expect(header_bounds(svg("100", "50", "translate(0.0000, 0.0000)"))).to eq([0, 0, 100, 50])
  end

  it "does not match a nonzero third argument" do
    expect(header_bounds(svg("100", "50", "translate(0.0000, 0.00 05)"))).to eq([0, 0, 100, 50])
  end

  it "does not match a legacy group nested below the header group" do
    nested = %(<g transform="#{legacy}"></g>)
    doc = %(<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50">#{header_group(nested)}</svg>)
    expect(header_bounds(doc)).to eq([0, 0, 100, 50])
  end

  it "does not match when the legacy group is not first" do
    doc = %(<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50">#{header_group('')}) \
          "<g transform=\"#{legacy}\"></g></svg>"
    expect(header_bounds(doc)).to eq([0, 0, 100, 50])
  end

  it "keeps existing behavior for dimensions of 2 or less" do
    expect(header_bounds(svg("2", "2", legacy))).to eq([0, 0, 2, 2])
  end

  it "keeps existing behavior for fractional dimensions" do
    expect(header_bounds(svg("100.5", "50", legacy))).to eq([0, 0, 100, 50])
  end
end
