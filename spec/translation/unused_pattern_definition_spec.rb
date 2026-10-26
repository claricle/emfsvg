# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Unused canonical pattern definitions" do
  let(:definition) do
    ['<defs><image id="img-1" x="0" y="0" width="8" height="8" ' \
     'xlink:href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAALklEQVQYlc3OoQ0AMAwD' \
     'wf/sv7NDqqqkwTGzzsBCknCj8PaaUKEmTM7ghwAu+NCtxSQHJKY49QAAAABJRU5ErkJgggAA"  preserveAspectRatio="none" />' \
     '<pattern id="img-1-ref" x="0" y="0" width="8" height="8" patternUnits="userSpaceOnUse" >',
     '<use id="img-1-ign" xlink:href="#img-1" /></pattern></defs>'].join("\n")
  end
  let(:draw) { '<rect x="20" y="21" width="3" height="4" fill="#ff0000"/>' }
  let(:rendered_draw) do
    '<path style="fill:#ff0000" d="M 20.0000,21.0000 L 23.0000,21.0000 ' \
      'L 23.0000,25.0000 L 20.0000,25.0000 Z" />'
  end
  let(:body) { draw + definition + draw }
  let(:svg) { %(<svg xmlns:xlink="http://www.w3.org/1999/xlink" width="40" height="40">#{body}</svg>) }
  let(:bytes) { Emfsvg.from_svg(svg) }
  let(:wires) { Emf.parse(bytes).records.map(&:wire) }
  let(:output) { Emfsvg.from_bytes(bytes) }
  let(:brushes) { wires.grep(Emf::Emr::Binary::Records::CreateDibPatternBrushPt) }

  it "restores the exact PNG and pattern block in drawing order" do
    expect(output).to include("#{definition}\n")
    expect(output.index(rendered_draw)).to be < output.index("<defs>")
    expect(output.rindex(rendered_draw)).to be > output.index("</defs>")
    expect(brushes.size).to eq(1)
  end

  it "leaves the created brush unselected and following draws unchanged" do
    expect(brushes.size).to eq(1)
    handle = brushes.first.ih_brush.to_i
    selections = wires.grep(Emf::Emr::Binary::Records::SelectObject).map { |wire| wire.ih_object.to_i }
    expect(selections).not_to include(handle)
    expect(output.scan(rendered_draw).size).to eq(2)
  end

  it "matches the pinned C renderer for freshly emitted wire", :live_reference do
    Dir.mktmpdir("unused-pattern-") do |directory|
      path = File.join(directory, "pattern.emf")
      File.binwrite(path, bytes)
      expect(Emfsvg::Compat.generate_reference(path)).to eq(output)
    end
  end

  %w[#img-1-ref url(#img-1-ref)].each do |paint|
    context "with a selected #{paint} pattern" do
      let(:body) do
        %(#{definition}<rect x="2" y="3" width="10" height="11" fill="#{paint}"/>#{draw}) +
          %(<rect x="20" y="3" width="10" height="11" fill="#{paint}"/>)
      end

      it "reuses the bitmap brush around a solid draw" do
        expect(brushes.size).to eq(1)
        handle = brushes.first.ih_brush.to_i
        selections = wires.grep(Emf::Emr::Binary::Records::SelectObject).map { |wire| wire.ih_object.to_i }
        expect(selections.count(handle)).to eq(2)
        expect(output).to include(definition, 'fill="#img-1-ref"', 'style="fill:#ff0000"')
        expect(output.lines.grep(/<(?:rect|path) /).size).to eq(2)
        expect(Emfsvg.from_bytes(Emfsvg.from_svg(output))).to eq(output)
      end
    end
  end

  context "with a second distinct unused definition" do
    let(:second_png) do
      "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAGElEQVQYlWP4jwQYGhj+o/OZGAiA4aEAACaCGvUCf+JhAAAAAElFTkSuQmCC"
    end
    let(:second_definition) do
      definition.gsub("img-1", "img-2").sub(/base64,[^"]+/, "base64,#{second_png}")
    end
    let(:body) { definition + draw + second_definition + draw }

    it "preserves both PNG variants and image numbering without changing draws" do
      expect(brushes.size).to eq(2)
      expect(output).to include(definition, second_definition)
      expect(output.scan(rendered_draw).size).to eq(2)
    end
  end

  context "with a later pattern reference" do
    let(:body) { %(#{definition}<unknown fill="url(#img-1-ref)"/>) }

    it "does not mistake a selected resource for an unused creation" do
      expect(brushes).to be_empty
    end
  end

  context "with a stylesheet" do
    let(:body) { %(#{definition}<style>rect { fill: url(#img-1-ref); }</style>#{draw}) }

    it "does not infer an unused resource through CSS" do
      expect(brushes).to be_empty
    end
  end

  context "with a later image reference" do
    let(:body) { %(#{definition}<use xlink:href="#img-1"/>) }

    it "keeps the referenced resource out of unused provenance" do
      expect(brushes).to be_empty
    end
  end

  [[:ordinary_id, "img-1", "custom"],
   [:different_units, "userSpaceOnUse", "objectBoundingBox"],
   [:different_use, 'xlink:href="#img-1"', 'xlink:href="#other"'],
   [:dimension_mismatch, 'width="8"', 'width="9"'],
   [:invalid_png, "iVBOR", "xxxxx"]].each do |name, before, after|
    context "with #{name}" do
      let(:body) { definition.gsub(before, after) + draw }

      it "preserves ordinary resource behavior and the following draw" do
        expect(brushes).to be_empty
        expect(output).not_to include("<pattern ")
        expect(output).to include('style="fill:#ff0000"')
      end
    end
  end
end
