# frozen_string_literal: true

require "spec_helper"
require "nokogiri"
require "libpng"

RSpec.describe Emfsvg::PngDecoder do
  it "decodes a 1x1 PNG to RGBA pixels" do
    # Generate a 1x1 red pixel PNG using libpng's encode
    rgba = [255, 0, 0, 255].pack("C*")
    png = Libpng.encode(1, 1, rgba, pixel_format: "RGBA")

    result = described_class.decode(png)
    expect(result.width).to eq(1)
    expect(result.height).to eq(1)
    expect(result.pixels.bytes[0, 4]).to eq([255, 0, 0, 255])
  end

  it "returns nil on empty input" do
    expect(described_class.decode(nil)).to be_nil
    expect(described_class.decode("")).to be_nil
  end

  it "returns nil on invalid PNG bytes" do
    expect(described_class.decode("not a png")).to be_nil
  end
end

RSpec.describe Emfsvg::DibEncoder do
  it "encodes 1x1 RGBA pixels to a 44-byte DIB (40-byte header + 4 pixel bytes)" do
    rgba = [255, 0, 0, 255].pack("C*")
    dib = described_class.encode(1, 1, rgba)
    expect(dib.bytesize).to eq(44)

    # Header: biSize=40, biWidth=1, biHeight=1, biPlanes=1, biBitCount=32, ...
    header = dib.bytes[0, 40].pack("C*")
    expect(header.unpack1("V")).to eq(40)           # biSize
    expect(header.unpack1("V", offset: 4)).to eq(1) # biWidth
    expect(header.unpack1("V", offset: 8)).to eq(1) # biHeight
  end

  it "swaps RGBA → BGRA in pixel array" do
    rgba = [255, 0, 0, 255].pack("C*")
    dib = described_class.encode(1, 1, rgba)
    expect(dib.bytes[40, 4]).to eq([0, 0, 255, 255]) # BGRA
  end
end

RSpec.describe Emfsvg::Translation::Handlers::ImageHandler do
  let(:context) { Emfsvg::Translation::Context.new }

  def image_node(attrs)
    attrs_str = attrs.map { |k, v| %(#{k}="#{v}") }.join(" ")
    Emfsvg::Svg::Element.from_node(Nokogiri::XML("<image #{attrs_str}/>").root)
  end

  it "skips non-PNG images silently" do
    element = image_node(
      "x" => "0", "y" => "0", "width" => "1", "height" => "1",
      "xlink:href" => "data:image/jpeg;base64,AAAA"
    )
    described_class.call(element, context)
    expect(context.records).to be_empty
  end

  it "skips non-data: URIs" do
    element = image_node(
      "x" => "0", "y" => "0", "width" => "1", "height" => "1",
      "xlink:href" => "https://example.com/foo.png"
    )
    described_class.call(element, context)
    expect(context.records).to be_empty
  end

  it "emits StretchDIBits for a 1x1 PNG data URI" do
    png = Libpng.encode(1, 1, [255, 0, 0, 255].pack("C*"), pixel_format: "RGBA")
    href = "data:image/png;base64,#{Base64.strict_encode64(png)}"

    element = image_node(
      "x" => "0", "y" => "0", "width" => "1", "height" => "1",
      "xlink:href" => href
    )
    described_class.call(element, context)

    record = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::StretchDIBits) }
    expect(record).not_to be_nil
    expect(record.wire.cb_bmi_src).to eq(40)
    expect(record.wire.cb_bits_src).to eq(4)
  end
end
