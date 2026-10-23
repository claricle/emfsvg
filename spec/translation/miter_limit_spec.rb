# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SVG stroke miter limits" do
  let(:svg) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
        <path d="M 0,0 L 50,50 L 100,0" fill="none" stroke="black" stroke-linejoin="miter" stroke-miterlimit="5" />
      </svg>
    SVG
  end

  it "preserves explicit miter limits through EMF records and SVG output" do
    [1, 5, 8].each do |limit|
      source = svg.sub('stroke-miterlimit="5"', %(stroke-miterlimit="#{limit}"))
      bytes = Emfsvg.from_svg(source)
      records = Emf.parse(bytes).records.map(&:wire)
      miter_records = records.grep(Emf::Emr::Binary::Records::SetMiterLimit)
      rendered = Emfsvg.from_bytes(bytes)

      expect(miter_records.map(&:miter_limit)).to eq([limit.to_f])
      expect(rendered).to include(%(stroke-miterlimit="#{format('%.4f', limit.to_f)}"))
    end
  end

  it "keeps the existing miter default when the attribute is absent" do
    bytes = Emfsvg.from_svg(svg.sub(' stroke-miterlimit="5"', ""))
    records = Emf.parse(bytes).records.map(&:wire)
    miter_records = records.grep(Emf::Emr::Binary::Records::SetMiterLimit)

    expect(miter_records.map(&:miter_limit)).to eq([10.0])
    expect(Emfsvg.from_bytes(bytes)).to include('stroke-miterlimit="10.0000"')
  end

  %w[test-039.svg test-040.svg].each do |filename|
    it "preserves every explicit miter limit in #{filename}" do
      source = File.read(File.join("spec/fixtures/emfsvg_golden", filename))
      expected_limits = source.scan(/stroke-miterlimit="([^"]+)"/).flatten
      bytes = Emfsvg.from_svg(source)
      records = Emf.parse(bytes).records.map(&:wire)
      actual_limits = records.grep(Emf::Emr::Binary::Records::SetMiterLimit).map(&:miter_limit)

      expect(expected_limits.size).to eq(120)
      explicit_limits = expected_limits.map(&:to_f)
      expect(actual_limits.select { |limit| explicit_limits.include?(limit) }).to eq(explicit_limits)
    end
  end
end
