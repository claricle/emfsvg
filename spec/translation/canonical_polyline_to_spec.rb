# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe "canonical PolylineTo provenance" do
  let(:fixture_name) { "test-039" }
  let(:source_lines) { File.readlines("spec/fixtures/emfsvg_golden/#{fixture_name}.svg") }
  let(:path) { source_lines.fetch(28).strip }
  let(:svg) { %(<svg xmlns="http://www.w3.org/2000/svg" width="14030" height="9920">#{path}</svg>) }
  let(:bytes) { Emfsvg.from_svg(svg) }
  let(:parsed) { Emf.parse(bytes) }
  let(:records) { parsed.records.map(&:wire) }
  let(:output) { Emfsvg.from_bytes(bytes) }

  shared_examples "a native current-position polyline" do
    it "serializes the initial move and six PolylineTo vertices with exact output" do
      expect(parsed.errors).to be_empty
      expect(records.grep(Emf::Emr::Binary::Records::MoveToEx).size).to eq(1)
      expect(records.grep(Emf::Emr::Binary::Records::PolylineTo).size).to eq(1)
      move = records.grep(Emf::Emr::Binary::Records::MoveToEx).first
      polyline = records.grep(Emf::Emr::Binary::Records::PolylineTo).first

      expect([move.origin.x, move.origin.y]).to eq([5100, 1800])
      expect(polyline.aptl.map { |point| [point.x, point.y] }).to eq(
        [[5200, 1800], [5300, 1900], [5300, 2000], [5200, 2100], [5100, 2000], [5100, 1900]]
      )
      expect(records.grep(Emf::Emr::Binary::Records::Polyline)).to be_empty
      expect(output).to include(path)
    end
  end

  include_examples "a native current-position polyline"

  context "with corpus fixture 040" do
    let(:fixture_name) { "test-040" }

    include_examples "a native current-position polyline"
  end

  context "with canonical round joins" do
    let(:path) do
      super().sub('stroke-linejoin="miter"  stroke-miterlimit="8.0000"', 'stroke-linejoin="round"')
    end

    it "matches the pinned C renderer on the freshly serialized EMF", :live_reference do
      expect(records.grep(Emf::Emr::Binary::Records::PolylineTo).size).to eq(1)
      expect(output).to include(path)

      Tempfile.create(["canonical-polyline-to", ".emf"]) do |file|
        file.binmode
        file.write(bytes)
        file.flush

        expect(Emfsvg::Compat.generate_reference(file.path)).to eq(output)
      end
    end
  end

  context "with the neighboring canonical one-space Polyline" do
    let(:path) { source_lines.fetch(26).strip }

    it "preserves native Polyline and its exact rendered spelling" do
      expect(records.grep(Emf::Emr::Binary::Records::Polyline).size).to eq(1)
      expect(records.grep(Emf::Emr::Binary::Records::PolylineTo)).to be_empty
      expect(output).to include(path)
    end
  end

  [
    ["  fill=", " fill="],
    ["  fill=", "   fill="],
    ["M 5100.0000,1800.0000", "M 5100,1800"],
    ['stroke="#FF0000" stroke-width="10.0000"', 'stroke-width="10.0000" stroke="#FF0000"']
  ].each do |before, after|
    context "with ordinary SVG spelling #{after.inspect}" do
      let(:path) { super().sub(before, after) }

      it "preserves the generic Polyline strategy and geometry" do
        expect(records.grep(Emf::Emr::Binary::Records::Polyline).size).to eq(1)
        expect(records.grep(Emf::Emr::Binary::Records::PolylineTo)).to be_empty
        expect(output).to include('d="M 5100.0000,1800.0000 L 5200.0000,1800.0000')
      end
    end
  end
end
