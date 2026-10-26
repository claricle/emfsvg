# frozen_string_literal: true

require "spec_helper"

RSpec.describe "private drawing hint compatibility" do
  include Emfsvg::SpecSupport::DrawingHintHelpers

  let(:legacy_rectangle) do
    '<rect x="10.25" y="20.50" width="30.75" height="40.125" fill="#AABBCC"/>'
  end

  let(:cosmetic_path) do
    '<path d="M 300,3700 L 500,3900 L 300,4100" stroke="#FF00FF" stroke-width="1.0000" ' \
      'stroke-dasharray="25.0000,25.0000" stroke-linecap="round" stroke-linejoin="round" fill="none"/>'
  end

  let(:jpeg_base64) do
    "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGB" \
      "YUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wgARCAAK" \
      "AAoDAREAAhEBAxEB/8QAFgABAQEAAAAAAAAAAAAAAAAABQYH/8QAFQEBAQAAAAAAAAAAAAAAAAAABQf/2gAMAwEAAhADEAAAAY4hpBODYRQ6qt" \
      "ZDP//EABwQAAEDBQAAAAAAAAAAAAAAAAMAAQUCBBITIf/aAAgBAQABBQKJvxaHnugJUsnX/8QAHxEAAgECBwAAAAAAAAAAAAAAAAECAwQFBhEV" \
      "ISIx/9oACAEDAQE/AczXm46xj6Twrs+CqNI//8QAHhEAAQQBBQAAAAAAAAAAAAAAAAECAyEFBhEUFmL/2gAIAQIBAT8BiwnNpEOleTT7UqhsbN" \
      "ko/8QAGhAAAgIDAAAAAAAAAAAAAAAAAAECMiIxkf/aAAgBAQAGPwJSk8ixZ9Ns/8QAGRAAAgMBAAAAAAAAAAAAAAAAAAERIVHx/9oACAEBAAE/" \
      "IUlKlLSBgrAu8f/aAAwDAQACAAMAAAAQ2Q//xAAaEQEBAAIDAAAAAAAAAAAAAAABABEhQcHw/8QAGhEBAA" \
      "IDAQAAAAAAAAAAAAAAAQAhMUGRwf/aAAgBAgEBPxCrfg0PMW1ciKuDRP/EABkQAQEBAAMAAAAAAAAAAAAAAAEAESExQf/aAAgBAQABPxAxsaVp" \
      "hAAoA9RBCDgBQ4Ki+6v/2Q=="
  end

  it "restores the exact legacy rectangle tag" do
    svg = %(<svg width="14030" height="9920">#{legacy_rectangle}</svg>)
    rendered = Emfsvg.from_bytes(Emfsvg.from_svg(svg))

    expect(rendered).to include(legacy_rectangle)
  end

  it "retains the cosmetic raw path spelling through a second conversion" do
    svg = %(<svg width="14030" height="9920">#{cosmetic_path}</svg>)
    first = Emfsvg.from_bytes(Emfsvg.from_svg(svg))
    second = Emfsvg.from_bytes(Emfsvg.from_svg(first))

    expect(first).to include('stroke-width="1.0000"')
    expect(second).to include('stroke-width="1.0000"')
  end

  it "preserves JPEG MIME type and payload without leaking its hint to a following draw" do
    expected_uri = "data:image/jpeg;base64,#{jpeg_base64}"
    following_rect = '<rect x="50" y="60" width="3" height="4" fill="#123456"/>'
    svg = %(<svg width="100" height="100"><image x="12" y="13" width="30" height="40" href="#{expected_uri}"/> ) +
          %(#{following_rect}</svg>)
    rendered = Emfsvg.from_bytes(Emfsvg.from_svg(svg))

    expect(rendered).to include(expected_uri)
    expect(rendered).to include(following_rect)
  end

  it "keeps generated provenance bounded for unusually long numeric spelling" do
    rectangle = legacy_rectangle.sub('x="10.25"', %(x="#{'0' * 400}10.25"))
    bytes = Emfsvg.from_svg(%(<svg width="100" height="100">#{rectangle}</svg>))
    comments = Emf.parse(bytes).records.map(&:wire).grep(Emf::Emr::Binary::Records::Comment)

    expect(comments).to be_empty
    expect(Emfsvg.from_bytes(bytes)).to include("#aabbcc")
  end

  describe "hint decoding" do
    let(:record) { Struct.new(:wire).new(Struct.new(:to_binary_s).new("draw")) }
    let(:valid_hint) { Emfsvg::DrawingHint.encode(record, "jpeg", []) }

    it "accepts a well-formed versioned hint and rejects malformed payload boundaries" do
      expect(Emfsvg::DrawingHint.decode(comment_wire(valid_hint))).to include("kind" => "jpeg")
      expect(Emfsvg::DrawingHint.decode(comment_wire("emfsvg-draw:2:{}"))).to be_nil
      expect(Emfsvg::DrawingHint.decode(comment_wire(valid_hint, 513))).to be_nil
      expect(Emfsvg::DrawingHint.decode(comment_wire("#{valid_hint}x"))).to be_nil
    end
  end

  describe "binding and consumption" do
    let(:rectangle_svg) do
      '<svg width="100" height="100"><rect x="10.25" y="20.50" width="30.75" height="40.125" fill="#AABBCC"/></svg>'
    end
    let(:comment_record_type) { Emf::Emr::Binary::TypeCodes::COMMENT }
    it "rejects a valid hint when its following draw record has changed" do
      bytes = Emfsvg.from_svg(rectangle_svg).dup
      comment = record_spans(bytes).find { |_, _, type| type == comment_record_type }
      draw = record_spans(bytes).find { |offset, _, _| offset == comment[0] + comment[1] }
      bytes.setbyte(draw[0] + 8, bytes.getbyte(draw[0] + 8) ^ 1)

      expect(Emfsvg.from_bytes(bytes)).not_to include(legacy_rectangle)
    end

    it "rejects rectangle spelling when the valid hint paint disagrees with the selected brush" do
      bytes = Emfsvg.from_svg(rectangle_svg).dup
      comment = record_spans(bytes).find { |_, _, type| type == comment_record_type }
      payload = bytes.byteslice(comment[0], comment[1])
      expect(payload).to include("#AABBCC")
      bytes[comment[0], comment[1]] = payload.sub("#AABBCC", "#FF0000")

      expect(Emfsvg.from_bytes(bytes)).not_to include(legacy_rectangle)
    end

    it "consumes a valid hint on the first intervening record" do
      bytes = Emfsvg.from_svg(rectangle_svg).dup
      spans = record_spans(bytes)
      comment_index = spans.index { |_, _, type| type == comment_record_type }
      prior = spans[comment_index - 1]
      comment = spans[comment_index]
      chunk = bytes.byteslice(comment[0], comment[1])
      bytes[prior[0], comment[1] + prior[1]] = chunk + bytes.byteslice(prior[0], prior[1])

      expect(Emfsvg.from_bytes(bytes)).not_to include(legacy_rectangle)
    end
  end
end
