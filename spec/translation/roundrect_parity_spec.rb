# frozen_string_literal: true

require "spec_helper"

RSpec.describe "rounded rectangle parity" do
  let(:svg) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">
        <rect x="10" y="20" width="100" height="50" rx="5" ry="8" fill="red"/>
      </svg>
    SVG
  end

  it "preserves unequal corner radii through the public roundtrip" do
    bytes = Emfsvg.from_svg(svg)
    corners = Emf.parse(bytes).records.map(&:wire).grep(Emf::Emr::Binary::Records::RoundRect).first.szl_corner

    expect([corners.cx.to_i, corners.cy.to_i]).to eq([5, 8])
    expect(Emfsvg.from_bytes(bytes)).to include('rx="5.0000" ry="8.0000"')
  end

  it "preserves ordinary rectangle record selection and geometry" do
    bytes = Emfsvg.from_svg(svg.sub(' rx="5" ry="8"', ""))
    records = Emf.parse(bytes).records.map(&:wire)

    expect(records.grep(Emf::Emr::Binary::Records::RoundRect)).to be_empty
    expect(records.grep(Emf::Emr::Binary::Records::Rectangle).size).to eq(1)
    expect(Emfsvg.from_bytes(bytes)).to include('x="10.0000" y="20.0000" width="100.0000" height="50.0000"')
  end

  %w[EA-test-file-015 EA-test-file-030 EA-test-file-031].each do |name|
    context "with #{name}" do
      let(:corpus) { Emfsvg::SpecSupport::ParityCorpus.new.verify! }
      let(:entry) { corpus.fixtures.find { |fixture| fixture.fetch("name") == name } }

      it "preserves all rounded rectangle corners through the public roundtrip" do
        expected = File.read(corpus.artifact_path(entry, "round_trip"))
        actual = Emfsvg.from_bytes(Emfsvg.from_svg(expected))
        expected_corners = expected.scan(/<rect\b[^>]*\brx="[^"]*" ry="[^"]*"/)

        expect(expected_corners).not_to be_empty
        expect(actual.scan(/<rect\b[^>]*\brx="[^"]*" ry="[^"]*"/)).to eq(expected_corners)
      end

      it "preserves the complete direct rendering baseline" do
        expected = File.read(corpus.artifact_path(entry, "golden"))

        expect(Emfsvg.from_file(corpus.source_path(entry))).to eq(expected)
      end
    end
  end
end
