# frozen_string_literal: true

require "spec_helper"

RSpec.describe "adjacent identical text state" do
  def translate(children)
    Emfsvg.from_svg(%(<svg width="100" height="100">#{children}</svg>))
  end

  def text(attributes = "", content = "<![CDATA[]]>")
    %(<text x="2" y="20" font-family="Arial" font-size="0" #{attributes}>#{content}</text>)
  end

  def records(bytes)
    parsed = Emf.parse(bytes)
    expect(parsed.errors).to be_empty
    parsed.records
  end

  def font_count(bytes)
    records(bytes).count { |record| record.wire.i_type == 82 }
  end

  it "retains 300 empty text draws with one complete font lifetime" do
    bytes = translate(text * 300)
    types = records(bytes).map { |record| record.wire.i_type.to_i }

    expect(types.count(84)).to eq(300)
    expect(types.count(82)).to eq(1)
    expect(types.count(40)).to eq(1)
    expect(types.size).to eq(306)
    expect(Emfsvg.from_bytes(bytes).scan("<![CDATA[]]>").size).to eq(300)
  end

  it "uses a single selected font without nested saves or early deletion" do
    types = records(translate(text + text)).map { |record| record.wire.i_type.to_i }

    expect(types).to eq([82, 37, 24, 22, 84, 84, 40, 14])
  end

  {
    "font-family" => "Calibri", "font-size" => "12", "font-weight" => "700",
    "font-style" => "italic", "fill" => "#ff0000", "text-anchor" => "end"
  }.each do |attribute, value|
    it "starts a new lifetime when #{attribute} changes" do
      changed = text.sub(/#{attribute}="[^"]*"/, %(#{attribute}="#{value}"))
      changed = text(%(#{attribute}="#{value}")) if changed == text
      expect(font_count(translate((text * 2) + (changed * 2) + (text * 2)))).to eq(3)
    end
  end

  it "reuses state while preserving different text contents and positions" do
    first = text("", "one")
    second = text("", "two").sub('x="2"', 'x="9"')
    bytes = translate(first + second)
    output = Emfsvg.from_bytes(bytes)

    expect(font_count(bytes)).to eq(1)
    expect(output).to include('x="2.0000"', 'x="9.0000"', "<![CDATA[one]]>", "<![CDATA[two]]>")
  end

  it "includes canonical LOGFONT rotation in the state boundary" do
    rotated = text('transform="rotate(-90, 2.0000, 20.0000) translate(0, 0.0000)"')
    bytes = translate((text * 2) + (rotated * 2) + (text * 2))

    expect(font_count(bytes)).to eq(3)
    expect(Emfsvg.from_bytes(bytes).scan("rotate(-90,").size).to eq(2)
  end

  it "ends reuse at an intervening ellipse and preserves following changed text" do
    first = text('fill="#112233"', "first")
    ellipse = '<ellipse cx="50" cy="50" rx="5" ry="10" fill="#abcdef"/>'
    last = '<text x="8" y="30" font-family="Calibri" font-size="12" fill="#ff0000" text-anchor="end">last</text>'
    bytes = translate(first + first + ellipse + first + last)
    output = Emfsvg.from_bytes(bytes)

    expect(font_count(bytes)).to eq(3)
    expect(output.scan("<![CDATA[first]]>").size).to eq(3)
    expect(output).to include("<![CDATA[last]]>", 'font-family="Calibri"', 'font-size="12.0000"', 'fill="#FF0000"')
    expect(output.scan("<ellipse ").size).to eq(1)
  end

  it "ends reuse at a group boundary even for an identity transform" do
    expect(font_count(translate(text + "<g>#{text}</g>" + text))).to eq(3)
  end

  it "keeps transformed text isolated from adjacent text" do
    transformed = text('transform="translate(1,2)"')
    expect(font_count(translate(text + transformed + transformed + text))).to eq(4)
  end

  it "keeps clipped text isolated and preserves a following unclipped text" do
    defs = '<defs><clipPath id="c"><rect x="0" y="0" width="10" height="10"/></clipPath></defs>'
    clipped = text('clip-path="url(#c)"')
    bytes = translate(defs + clipped + clipped + text)

    expect(font_count(bytes)).to eq(3)
    nodes = Emfsvg.from_bytes(bytes).scan(%r{<text .*?</text>})
    expect(nodes.size).to eq(3)
    expect(nodes.last).not_to include("clip-path")
  end
end
