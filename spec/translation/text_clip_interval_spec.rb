# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Canonical text clip intervals" do
  let(:source) { File.binread(File.expand_path("../fixtures/emfsvg_golden/test-039.svg", __dir__)) }
  let(:bytes) { Emfsvg.from_svg(source) }
  let(:records) { Emf.parse(bytes).records.map(&:wire) }
  let(:output) { Emfsvg.from_bytes(bytes).b }

  it "preserves every clip definition and text reference in test-039" do
    expect(Emf.parse(bytes).errors).to be_empty
    expect(output.lines.grep(/\A<defs><clipPath/)).to eq(source.lines.grep(/\A<defs><clipPath/))
    expect(output.lines.grep(/\A<text  clip-path/)).to eq(source.lines.grep(/\A<text  clip-path/))
  end

  it "selects the five matching pending polygons with balanced native scopes" do
    expect(records.grep(Emf::Emr::Binary::Records::SelectClipPath).map { |wire| wire.region_mode.to_i })
      .to eq([5] * 5)
    expect(records.grep(Emf::Emr::Binary::Records::SaveDc).size)
      .to eq(records.grep(Emf::Emr::Binary::Records::RestoreDc).size)
    expect(output.lines.grep(/\A<text  clip-path/).last).to eq(source.lines.grep(/\A<text  clip-path/).last)
  end

  context "with ordinary clip identifiers" do
    let(:source) { super().gsub(/clip-(\d+)/, 'ordinary-\1') }

    it "retains bounds clipping and separate text scopes" do
      expect(records.grep(Emf::Emr::Binary::Records::SelectClipPath)).to be_empty
      expect(output.scan("<clipPath ").size).to eq(22)
    end
  end

  context "with ordinary pending path spelling" do
    let(:source) { super().gsub('fill="none" stroke="none" />', 'stroke="none" fill="none" />') }

    it "retains bounds rather than selecting an unproven path" do
      expect(records.grep(Emf::Emr::Binary::Records::SelectClipPath)).to be_empty
      expect(output).to include("L 13550.0000,3900.0000 L 13550.0000,4300.0000")
    end
  end

  context "with different selected geometry" do
    let(:source) { super().sub(%r{13350\.0000(?=[^\n]+ Z" /></clipPath>)}, "13351.0000") }

    it "requires an exact match to the pending native path" do
      expect(records.grep(Emf::Emr::Binary::Records::SelectClipPath).size).to eq(0)
    end
  end

  context "with custom text handling" do
    let(:bytes) do
      registry = Emfsvg::Translation::HandlerRegistry.new
      document = Emfsvg::Svg::Parser.call(source)
      nodes = [document.root_element]
      until nodes.empty?
        node = nodes.shift
        registry.register(node.class, Emfsvg::Translation::EmfRenderer::DEFAULT_REGISTRY.handler_for(node))
        nodes.concat(node.children)
      end
      registry.register(Emfsvg::Svg::Elements::Text, Class.new(Emfsvg::Translation::Handlers::TextHandler))
      Emf.serialize(Emfsvg::Translation::EmfRenderer.call(document, registry: registry))
    end

    it "keeps custom state outside the canonical interval optimization" do
      expect(records.grep(Emf::Emr::Binary::Records::SelectClipPath)).to be_empty
      expect(output.scan("<clipPath ").size).to eq(22)
    end
  end

  context "with an ordinary transform" do
    let(:source) do
      super().sub("matrix(0.5505 -0.3178 0.3178 0.5505 0.0000 4459.5000)", "matrix(.5505 -.3178 .3178 .5505 0 4459.5)")
    end

    it "preserves conservative bounds clipping" do
      expect(records.grep(Emf::Emr::Binary::Records::SelectClipPath)).to be_empty
      expect(output.scan("<clipPath ").size).to eq(25)
    end
  end
end
