# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Mapped canonical Arc translation" do
  let(:source) { Emfsvg::SpecSupport::FixturePath.read_fixture("emfsvg_golden", "EA-test-file-004.svg") }

  it "preserves the full frozen SVG and both native Arc records" do
    bytes = Emfsvg.from_svg(source)
    parsed = Emf.parse(bytes)
    expect(parsed.errors).to be_empty
    expect(parsed.records.map(&:wire).grep(Emf::Emr::Binary::Records::Arc).size).to eq(2)
    expect(Emfsvg.from_bytes(bytes).b).to eq(source)
  end

  it "restores mapping before a subsequent ordinary line" do
    svg = source.sub(%r{</g>\s*</svg>},
                     '<line x1="10" y1="20" x2="30" y2="40" stroke="red"/></g></svg>')
    expect(Emfsvg.from_bytes(Emfsvg.from_svg(svg))).to include("M 10.0000,20.0000 L 30.0000,40.0000 ")
  end
end
