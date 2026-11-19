# frozen_string_literal: true

require "spec_helper"

# The 2x2 palette PNG tile used by the EA-PDF specification figures.
TILE_PNG = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0k" \
           "AAAACklEQVR4AWPAAAAAEgABKPhxBgAAAABJRU5ErkJggg=="

RSpec.describe Emfsvg::Svg::Elements::Pattern do
  def parse_element(markup)
    doc = Leptris::XML.parse(markup, options: Leptris::XML::ParseOptions.noblanks)
    described_class.from_node(doc.root)
  end

  it "parses the pattern id" do
    element = parse_element(<<~SVG)
      <pattern xmlns="http://www.w3.org/2000/svg" id="pattern23" width="100%" height="100%"
               viewBox="0 0 1 1" preserveAspectRatio="xMidYMid slice"/>
    SVG
    expect(element.id).to eq("pattern23")
  end

  it "parses a raster tile into an Image element" do
    element = parse_element(<<~SVG)
      <pattern xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
               id="pattern23" width="100%" height="100%" viewBox="0 0 1 1">
        <image width="1" height="1" xlink:href="data:image/png;base64,#{TILE_PNG}"/>
      </pattern>
    SVG
    expect(element.image).to be_a(Emfsvg::Svg::Elements::Image)
    expect(element.image.mime_type).to eq("image/png")
    expect(element.image.decoded_bytes).to start_with("\x89PNG".b)
  end

  it "leaves image nil when the pattern has no raster content" do
    element = parse_element(<<~SVG)
      <pattern xmlns="http://www.w3.org/2000/svg" id="img-1-ref">
        <use id="img-1-ign" xlink:href="#img-1"/>
      </pattern>
    SVG
    expect(element.image).to be_nil
  end

  it "is registered for the pattern element name" do
    expect(Emfsvg::Svg::Element.registry["pattern"]).to eq(described_class)
  end
end
