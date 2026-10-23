# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Adjacent identical clipped paths" do
  let(:path) { '<path clip-path="url(#clip)" d="M 10,10 L 20,20 L 10,20 Z" stroke="#ff0000" fill="#00ff00"/>' }
  let(:second_path) { path.sub("10,10", "30,10") }
  let(:between) { "" }
  let(:body) { %(#{path}#{between}#{second_path}<rect x="70" y="70" width="10" height="10" fill="#0000ff"/>) }
  let(:svg) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
        <defs>
          <clipPath id="clip"><rect x="0" y="0" width="50" height="50"/></clipPath>
          <clipPath id="other"><rect x="1" y="1" width="40" height="40"/></clipPath>
        </defs>
        #{body}
      </svg>
    SVG
  end
  let(:bytes) { Emfsvg.from_svg(svg) }
  let(:parsed) { Emf.parse(bytes) }
  let(:wires) { parsed.records.map(&:wire) }
  let(:output) { Emfsvg.from_bytes(bytes) }

  it "shares one balanced native DC scope and retains both drawings and the following unclipped rectangle" do
    expect(parsed.errors).to be_empty
    expect(wires.grep(Emf::Emr::Binary::Records::SaveDc).size).to eq(1)
    expect(wires.grep(Emf::Emr::Binary::Records::RestoreDc).map { |wire| wire.saved_dc.to_i }).to eq([-1])
    expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(1)
    expect(output.scan("<clipPath ").size).to eq(1)
    expect(output.lines.count { |line| line.start_with?("<path ") }).to eq(2)
    expect(output).to match(%r{<rect [^>]*x="70\.0000"[^>]*fill="#0000FF"[^>]*/>})
    rect = output.lines.find { |line| line.include?('x="70.0000"') }
    expect(rect).not_to include("clip-path")
  end

  context "when the pen color changes" do
    let(:second_path) { path.sub("#ff0000", "#0000ff") }

    it "shares the clip scope and retains both colors" do
      expect(wires.grep(Emf::Emr::Binary::Records::SaveDc).size).to eq(1)
      expect(output).to include('stroke="#FF0000"', 'stroke="#0000FF"')
    end
  end

  context "when the pen width changes" do
    let(:second_path) { path.sub("<path ", '<path stroke-width="3" ') }

    it "shares the clip scope and retains the changed style" do
      expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(1)
      expect(output).to include('stroke-width="3.0000"')
    end
  end

  context "when the brush changes" do
    let(:second_path) { path.sub("#00ff00", "#0000ff") }

    it "shares the clip scope and retains the changed style" do
      expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(1)
      expect(output).to include('fill="#00FF00"', 'fill="#0000FF"')
    end
  end

  context "when the pen cap and join change" do
    let(:second_path) { path.sub("<path ", '<path stroke-linecap="square" stroke-linejoin="bevel" ') }

    it "shares the clip scope and retains the changed pen style" do
      expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(1)
      expect(output).to include('stroke-linecap="square"', 'stroke-linejoin="bevel"')
    end
  end

  context "with a custom path handler" do
    let(:bytes) do
      registry = Emfsvg::Translation::HandlerRegistry.new
      registry.register(Emfsvg::Svg::Elements::Path, Class.new(Emfsvg::Translation::Handlers::PathHandler))
      document = Emfsvg::Svg::Parser.call(svg)
      Emf.serialize(Emfsvg::Translation::EmfRenderer.call(document, registry: registry))
    end

    it "retains independent scopes because custom handler state is unknown" do
      expect(wires.grep(Emf::Emr::Binary::Records::SaveDc).size).to eq(2)
      expect(wires.grep(Emf::Emr::Binary::Records::RestoreDc).size).to eq(2)
    end
  end

  context "when the clip changes" do
    let(:second_path) { path.sub("url(#clip)", "url(#other)") }

    it "retains both clip definitions" do
      expect(output.scan("<clipPath ").size).to eq(2)
    end
  end

  context "when a transformed group intervenes" do
    let(:between) { '<g transform="translate(1,2)"><rect x="1" y="1" width="2" height="2"/></g>' }

    it "does not splice the group's restore" do
      expect(wires.grep(Emf::Emr::Binary::Records::SaveDc).size).to eq(3)
      expect(wires.grep(Emf::Emr::Binary::Records::RestoreDc).size).to eq(3)
      expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(2)
    end
  end

  context "when an unclipped shape intervenes" do
    let(:between) { '<path d="M 60,60 L 80,80" stroke="#000000" fill="none"/>' }

    it "closes the previous scope before drawing without a clip" do
      expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(2)
      middle = output.lines.find { |line| line.include?("60.0000,60.0000") }
      expect(middle).not_to include("clip-path")
    end
  end

  context "with three identical paths" do
    let(:body) { path + second_path + path }

    it "retains one outer save and one final restore for the whole run" do
      expect(wires.grep(Emf::Emr::Binary::Records::SaveDc).size).to eq(1)
      expect(wires.grep(Emf::Emr::Binary::Records::RestoreDc).size).to eq(1)
      expect(output.lines.count { |line| line.start_with?("<path ") }).to eq(3)
    end
  end

  context "when text intervenes" do
    let(:between) { '<text x="1" y="60">barrier</text>' }

    it "keeps separate shape scopes and the text" do
      expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(2)
      expect(output).to include("barrier")
    end
  end

  context "with consecutive cubic paths" do
    let(:path) { '<path clip-path="url(#clip)" d="M 10,10 C 11,12 13,14 20,20" stroke="#ff0000" fill="none"/>' }

    it "sets each start position inside the shared scope" do
      expect(wires.grep(Emf::Emr::Binary::Records::IntersectClipRect).size).to eq(1)
      expect(output).to include("10.0000,10.0000", "30.0000,10.0000")
      expect(output.lines.count { |line| line.start_with?("<path ") }).to eq(2)
    end
  end
end
