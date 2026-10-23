# frozen_string_literal: true

require "spec_helper"
require "leptris"

RSpec.describe "Canonical independently rounded text pivots" do
  [
    ["17.9564", "372.0833", "11.9910", "382.8753", "10.7919"],
    ["132.3494", "199.7150", "12.8399", "211.2708", "11.5559"],
    ["16.3590", "238.3281", "13.9615", "250.8934", "12.5654"]
  ].each do |x, y, height, pivot, offset|
    it "preserves pivot #{pivot} and the following ordinary text" do
      transform = "rotate(270, #{x}, #{pivot}) translate(0, #{offset})"
      bytes = Emfsvg.from_svg(<<~SVG)
        <svg width="800" height="600">
          <text x="#{x}" y="#{y}" font-family="Arial" font-size="#{height}"
                transform="#{transform}">pivot</text>
          <text x="20" y="30" font-family="Arial" font-size="10">control</text>
        </svg>
      SVG
      expect(Emf.parse(bytes).errors).to be_empty
      texts = Leptris::XML.parse(Emfsvg.from_bytes(bytes)).xpath("//*[local-name()='text']")
      expect(texts.map { |text| [text["x"], text["y"], text["font-size"], text["transform"], text.text] })
        .to eq([[x, y, height, transform, "pivot"], ["20.0000", "30.0000", "10.0000", nil, "control"]])
      expect(texts.first.parent).to eq(texts.last.parent)
      expect(Emf.parse(bytes).records.map(&:wire).grep(Emf::Emr::Binary::Records::SetWorldTransform)).to be_empty
    end
  end
end
