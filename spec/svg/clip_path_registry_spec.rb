# frozen_string_literal: true

require "spec_helper"
require "nokogiri"

RSpec.describe Emfsvg::Svg::ClipPathRegistry do
  describe ".from_document" do
    it "collects <clipPath> definitions by id" do
      svg = <<~SVG
        <svg>
          <defs>
            <clipPath id="clip1"><rect x="0" y="0" width="100" height="50"/></clipPath>
          </defs>
        </svg>
      SVG
      document = Emfsvg::Svg::Parser.call(svg)
      registry = described_class.from_document(document)
      clip = registry.lookup("url(#clip1)")
      expect(clip).to be_a(Emfsvg::Svg::Elements::ClipPath)
      expect(clip.id).to eq("clip1")
    end

    it "returns nil for missing references" do
      registry = described_class.new
      expect(registry.lookup("url(#missing)")).to be_nil
      expect(registry.lookup(nil)).to be_nil
      expect(registry.lookup("not-a-url")).to be_nil
    end

    it "finds clipPaths nested inside groups" do
      svg = <<~SVG
        <svg>
          <g>
            <defs>
              <clipPath id="nested"><rect/></clipPath>
            </defs>
          </g>
        </svg>
      SVG
      document = Emfsvg::Svg::Parser.call(svg)
      registry = described_class.from_document(document)
      expect(registry.lookup("url(#nested)")).not_to be_nil
    end
  end
end

RSpec.describe Emfsvg::Svg::Elements::ClipPath do
  it "exposes rectangular_bounds for a single-rect clip" do
    node = Nokogiri::XML('<clipPath id="c"><rect x="10" y="20" width="100" height="50"/></clipPath>').root
    clip = described_class.from_node(node)
    expect(clip.rectangular_bounds).to eq([10.0, 20.0, 110.0, 70.0])
  end

  it "returns nil rectangular_bounds for non-rect clips" do
    node = Nokogiri::XML('<clipPath id="c"><circle cx="0" cy="0" r="10"/></clipPath>').root
    clip = described_class.from_node(node)
    expect(clip.rectangular_bounds).to be_nil
  end
end
