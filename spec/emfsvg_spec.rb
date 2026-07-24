# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg do
  it "exposes a VERSION" do
    expect(Emfsvg::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end

  describe "error hierarchy" do
    it "has Emfsvg::Error as base" do
      expect(Emfsvg::Error).to be < StandardError
    end

    it "has Emfsvg::FormatError" do
      expect(Emfsvg::FormatError).to be < Emfsvg::Error
    end

    it "has Emfsvg::RenderError" do
      expect(Emfsvg::RenderError).to be < Emfsvg::Error
    end
  end

  describe ".from_file" do
    let(:fixture) { Emfsvg::SpecSupport::FixturePath.read_fixture("image1.emf") }

    it "renders the simple EMF fixture to a non-empty SVG" do
      svg = described_class.from_file(Emfsvg::SpecSupport::FixturePath.fixture("image1.emf"))
      expect(svg).to start_with(%(<?xml version="1.0"))
      expect(svg).to include("<svg")
      expect(svg).to include("</svg>")
      expect(svg.bytesize).to be > 1000
    end
  end

  describe ".from_bytes" do
    let(:bytes) { Emfsvg::SpecSupport::FixturePath.read_fixture("image1.emf") }

    it "renders identical SVG to from_file" do
      via_bytes = described_class.from_bytes(bytes)
      via_file = described_class.from_file(Emfsvg::SpecSupport::FixturePath.fixture("image1.emf"))
      expect(via_bytes).to eq(via_file)
    end
  end

  describe ".to_svg" do
    let(:metafile) { Emf.parse(Emfsvg::SpecSupport::FixturePath.read_fixture("image1.emf")) }

    it "renders from a parsed Metafile" do
      svg = described_class.to_svg(metafile)
      expect(svg).to include("<svg")
    end

    it "honors width override" do
      svg = described_class.to_svg(metafile, width: 400, height: 300)
      expect(svg).to include('width="400"')
      expect(svg).to include('height="300"')
    end

    it "honors namespace prefix" do
      svg = described_class.to_svg(metafile, namespace: "svg")
      expect(svg).to include("xmlns:svg")
    end
  end
end
