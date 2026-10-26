# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Scoped line origins" do
  let(:line) do
    '<path d="M 180662.7273,165544.1138 L 180662.7273,227868.5690" ' \
      'stroke="#000000" stroke-width="295.4545" fill="none"/>'
  end
  let(:source) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
      #{line}<path d="M 1.2345,2.3456 L 3.4567,4.5678" stroke="#000000" fill="none"/>
      </svg>
    SVG
  end
  let(:bytes) { Emfsvg.from_svg(source) }
  let(:parsed) { Emf.parse(bytes) }
  let(:wires) { parsed.records.map(&:wire) }
  let(:output) { Emfsvg.from_bytes(bytes) }

  it "preserves the overflowing line and subsequent decimals through serialized EMF" do
    expect(parsed.errors).to be_empty
    expect(output).to include("180662.7273,165544.1138", "180662.7273,227868.5690", "1.2345,2.3456", "3.4567,4.5678")
    origins = wires.grep(Emf::Emr::Binary::Records::SetViewportOrgEx).map { |wire| [wire.origin.x.to_i, wire.origin.y.to_i] }
    expect(origins).to eq([[0, 196_706], [0, 0]])
    expect(wires.grep(Emf::Emr::Binary::Records::CreatePen).first.width.x.to_i).to eq(2_954_545)
  end

  context "when both axes need a local origin" do
    let(:line) { '<path d="M -227868.5690,227868.5690 L -227800.1234,227800.1234" stroke="#000000" fill="none"/>' }

    it "preserves both axes and resets the following draw" do
      expect(parsed.errors).to be_empty
      expect(output).to include("-227868.5690,227868.5690", "-227800.1234,227800.1234", "1.2345,2.3456")
    end
  end

  context "with an ordinary line" do
    let(:line) { '<path d="M 1.2345,2.3456 L 3.4567,4.5678" stroke="#000000" fill="none"/>' }

    it "keeps the ordinary zero origin without extra mapping records" do
      expect(wires.grep(Emf::Emr::Binary::Records::SetViewportOrgEx)).to be_empty
      expect(output).to include("1.2345,2.3456")
    end
  end

  context "with a relative command" do
    let(:line) { '<path d="M 180662.7273,165544.1138 l 0,62324.4552" stroke="#000000" fill="none"/>' }

    it "retains the existing conservative fallback" do
      expect(wires.grep(Emf::Emr::Binary::Records::SetViewportOrgEx)).to be_empty
      expect(wires.grep(Emf::Emr::Binary::Records::SetMapMode)).to be_empty
    end
  end

  context "when the span cannot fit int32 at the fixed scale" do
    let(:line) { '<path d="M -227868.5690,0 L 227868.5690,0" stroke="#000000" fill="none"/>' }

    it "retains the existing conservative fallback" do
      expect(wires.grep(Emf::Emr::Binary::Records::SetViewportOrgEx)).to be_empty
      expect(wires.grep(Emf::Emr::Binary::Records::SetMapMode)).to be_empty
    end
  end

  context "with a clipped line" do
    let(:line) do
      '<defs><clipPath id="ordinary"><rect x="0" y="0" width="300000" height="300000"/></clipPath></defs>' \
        '<path clip-path="url(#ordinary)" d="M 180662.7273,165544.1138 L 180662.7273,227868.5690" ' \
        'stroke="#000000" fill="none"/>'
    end

    it "does not move clip coordinates into the line's local origin" do
      expect(wires.grep(Emf::Emr::Binary::Records::SetViewportOrgEx)).to be_empty
      expect(parsed.errors).to be_empty
    end
  end
end
