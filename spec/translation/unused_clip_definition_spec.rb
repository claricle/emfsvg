# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Unused canonical clip definitions" do
  let(:definition) do
    '<defs><clipPath id="clip-16807"><path d="M 1.0000,2.0000 L 8.0000,2.0000 ' \
      'L 8.0000,9.0000 L 1.0000,9.0000 L 1.0000,2.0000 Z Z" /></clipPath></defs>'
  end
  let(:draw) { '<rect x="20" y="21" width="3" height="4" fill="#ff0000"/>' }

  def convert(body)
    bytes = Emfsvg.from_svg(%(<svg width="40" height="40">#{body}</svg>))
    [Emfsvg.from_bytes(bytes), Emf.parse(bytes).records.map(&:wire)]
  end

  it "preserves an unused definition in position and leaves following draws unclipped" do
    output, wires = convert(draw + definition + draw)
    expect(output.scan("<clipPath ").size).to eq(1)
    expect(output.index("<rect ")).to be < output.index("<defs>")
    expect(output.rindex("<rect ")).to be > output.index("</defs>")
    expect(output.lines.grep(/<rect /).size).to eq(2)
    expect(output.lines.grep(/<rect /)).to all(include('x="20.0000"', 'width="3.0000"'))
    expect(output).not_to include("clip-path=")
    expect(wires.grep(Emf::Emr::Binary::Records::SaveDc)).to be_empty
    resets = wires.grep(Emf::Emr::Binary::Records::ExtSelectClipRgn)
    expect(resets.map { |wire| [wire.cb_rgn_data.to_i, wire.dw_mode.to_i] }).to eq([[0, 5]])
  end

  it "keeps native popping scopes balanced around an unused definition" do
    output, wires = convert(%(<g transform="scale(2)">#{definition}#{draw}</g>#{draw}))
    stack = []
    clip = nil
    draws = []
    wires.each do |wire|
      case wire
      when Emf::Emr::Binary::Records::SaveDc then stack << clip
      when Emf::Emr::Binary::Records::RestoreDc
        expect(wire.saved_dc.to_i).to eq(-1)
        expect(stack.size).to eq(1)
        clip = stack.pop
      when Emf::Emr::Binary::Records::IntersectClipRect then clip = wire.rcl_clip.snapshot
      when Emf::Emr::Binary::Records::ExtSelectClipRgn
        expect([wire.cb_rgn_data.to_i, wire.dw_mode.to_i]).to eq([0, 5])
        clip = nil
      when Emf::Emr::Binary::Records::Rectangle then draws << clip
      end
    end
    expect(stack).to be_empty
    expect(draws).to eq([nil, nil])
    expect(output.scan("<clipPath ").size).to eq(1)
    output.lines.grep(/<rect /).each { |line| expect(line).not_to include("clip-path") }
  end

  it "does not materialize ordinary unused rectangular resources" do
    resource = '<defs><clipPath id="clip-16807"><rect x="1" y="2" width="7" height="7"/></clipPath></defs>'
    output, = convert(resource + draw)
    expect(output).not_to include("<clipPath ")
  end

  it "does not emit a definition that will be referenced later" do
    output, wires = convert(definition + draw.sub("<rect ", '<rect clip-path="url(#clip-16807)" '))
    expect(output.scan("<clipPath ").size).to eq(1)
    expect(output).to include('clip-path="url(#clip-16807)"')
    expect(wires.grep(Emf::Emr::Binary::Records::ExtSelectClipRgn)).to be_empty
  end

  it "keeps unused definitions after a real clip mutation untouched" do
    used = definition.sub("clip-16807", "used")
    clipped = draw.sub("<rect ", '<rect clip-path="url(#used)" ')
    output, wires = convert(used + clipped + definition + draw)
    expect(output.scan("<clipPath ").size).to eq(1)
    expect(wires.grep(Emf::Emr::Binary::Records::ExtSelectClipRgn)).to be_empty
    expect(output.lines.grep(/<rect /).last).not_to include("clip-path")
  end

  it "preserves consecutive unused definitions without adding save scopes" do
    output, wires = convert(definition + definition.sub("16807", "282475249") + draw)
    expect(output.scan("<clipPath ").size).to eq(2)
    expect(wires.grep(Emf::Emr::Binary::Records::SaveDc)).to be_empty
    expect(output.lines.grep(/<rect /).last).not_to include("clip-path")
  end

  [[:ordinary_id, ->(d) { d.sub("clip-16807", "custom") }],
   [:noncanonical, ->(d) { d.sub(" Z Z", " Z") }],
   [:nonrectangular, ->(d) { d.sub("8.0000,9.0000", "7.0000,9.0000") }],
   [:ordinary_source_spelling, ->(d) { d.sub('" />', '"/>') }]].each do |name, change|
    it "ignores #{name} unused resources" do
      output, = convert(change.call(definition) + draw)
      expect(output).not_to include("<clipPath ")
      expect(output.lines.grep(/<rect /).last).not_to include("clip-path")
    end
  end
end
