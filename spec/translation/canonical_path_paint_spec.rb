# frozen_string_literal: true

require "spec_helper"
require "leptris"

RSpec.describe "canonical open path paint provenance" do
  let(:source_lines) { File.readlines("spec/fixtures/emfsvg_golden/test-039.svg") }

  include Emfsvg::SpecSupport::CanonicalPathConversion

  [18, 19, 20, 21, 22, 23, 24].each do |line|
    it "preserves implicit fill closure and a single initial move on source line #{line}" do
      path = source_lines.fetch(line - 1).strip
      records, output = convert(path)

      expect(records.grep(Emf::Emr::Binary::Records::StrokeAndFillPath).size).to eq(1)
      expect(records.grep(Emf::Emr::Binary::Records::CloseFigure)).to be_empty
      expect(output.lines.find { |item| item.start_with?("<path ") }.strip).to eq(path)
    end
  end

  it "uses PolyBezierTo for the canonical single-move unfilled cubic" do
    path = source_lines.fetch(27).strip
    records, output = convert(path)

    expect(records.grep(Emf::Emr::Binary::Records::PolyBezierTo).size).to eq(1)
    expect(output).to include(path)
  end

  it "retains the explicit preceding move on the canonical PolyBezier" do
    path = source_lines.fetch(24).strip
    records, output = convert(path)

    expect(records.grep(Emf::Emr::Binary::Records::PolyBezier).size).to eq(1)
    expect(output).to include(path)
  end

  it "requires exact source spelling before choosing a filled path bracket" do
    path = source_lines.fetch(17).strip.sub("  fill=", " fill=")
    records, = convert(path)

    expect(records.grep(Emf::Emr::Binary::Records::Polyline).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::StrokeAndFillPath)).to be_empty
  end

  it "preserves the following unfilled drawing and its independent style" do
    first = source_lines.fetch(19).strip
    following = '<path d="M 1,2 L 3,4" fill="none" stroke="#0000FF"/>'
    records, output = convert(first + following)
    paths = Leptris::XML.parse(output).xpath("//*[local-name()='path']")

    expect(records.grep(Emf::Emr::Binary::Records::StrokeAndFillPath).size).to eq(1)
    expect(paths.size).to eq(2)
    expect(paths.first["fill"]).to eq("#808080")
    expect(paths.last["d"]).to eq("M 1.0000,2.0000 L 3.0000,4.0000 ")
    expect(paths.last["fill"]).to eq("none")
    expect(paths.last["stroke"]).to eq("#0000FF")
  end

  it "keeps ordinary SVG on its existing record strategy" do
    records, = convert('<path d="M 1,2 C 3,4 5,6 7,8" fill="none" stroke="black"/>')

    expect(records.grep(Emf::Emr::Binary::Records::PolyBezier).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::StrokePath)).to be_empty
  end
end
