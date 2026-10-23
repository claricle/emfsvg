# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::SvgBuilder do
  it "uses the renderer ceiling by default and rejects before extending output" do
    stub_const("Emfsvg::Renderer::MAX_OUTPUT_BYTES", 3)
    builder = described_class.new
    builder.raw("abc")
    expect { builder.raw("d") }.to raise_error(Emfsvg::ResourceLimitError) { |error|
      expect([error.resource, error.limit, error.actual]).to eq([:output_bytes, 3, 4])
    }
    expect(builder.to_s).to eq("abc")
  end

  it "counts bytes rather than characters" do
    builder = described_class.new(max_output_bytes: 2)
    builder.raw("é")
    expect { builder.raw("é") }.to raise_error(Emfsvg::ResourceLimitError)
    expect(builder.to_s.b).to eq("é".b)
  end

  it "guards every tag, closing tag, and newline append" do
    operations = [
      ->(builder) { builder.tag("rect", { "x" => "abc" }, single: true) },
      ->(builder) { builder.tag("g") { builder.raw("abc") } },
      ->(builder) { builder.rawln("abc") },
      ->(builder) { builder.raw("abc").newline }
    ]
    operations.each do |operation|
      accepted = described_class.new
      operation.call(accepted)
      accepted.to_s.bytesize.times do |limit|
        builder = described_class.new(max_output_bytes: limit)
        expect { operation.call(builder) }.to raise_error(Emfsvg::ResourceLimitError)
        expect(builder.to_s.bytesize).to be <= limit
      end
    end
  end

  it "rejects expanded text before allocating its escaped copy" do
    text = +"&&"
    builder = described_class.new(max_output_bytes: 9)
    expect(text).not_to receive(:gsub)
    expect { builder.text(text) }.to raise_error(Emfsvg::ResourceLimitError) { |error|
      expect(error.actual).to eq(10)
    }
    expect(builder.to_s).to eq("")
  end

  it "rejects expanded attributes before allocating their escaped copy" do
    value = +'"&'
    builder = described_class.new(max_output_bytes: 16)
    expect(value).not_to receive(:gsub)
    expect { builder.tag("g", { "a" => value }, single: true) }.to raise_error(Emfsvg::ResourceLimitError)
    expect(builder.to_s).to eq('<g a="')
  end

  it "preserves exact accepted bytes at the inclusive budget boundary" do
    expected = "<g a=\"&quot;&amp;&lt;&gt;\">é&amp;&lt;&gt;</g>\n<rect/>\n"
    builder = described_class.new(max_output_bytes: expected.bytesize)
    builder.tag("g", { "a" => '"&<>', "omitted" => nil }) { builder.text("é&<>") }
    builder.newline.tag("rect", single: true).rawln("")
    expect(builder.to_s.b).to eq(expected.b)
    expect(builder.to_s.bytesize).to eq(expected.bytesize)
  end
end
