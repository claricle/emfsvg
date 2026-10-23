# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Renderer resource guards" do
  let(:bytes) { Emfsvg::SpecSupport::FixturePath.read_fixture("image1.emf") }
  let(:model) { Emf.parse(bytes) }

  it "rejects invalid output dimensions before builder allocation or record materialization" do
    dimensions = %i[width height]
    [0, -1, Float::INFINITY, -Float::INFINITY, Float::NAN].each do |value|
      dimensions.each do |dimension|
        expect(Emfsvg::SvgBuilder).not_to receive(:new)
        expect(model).not_to receive(:each)
        expect do
          Emfsvg.to_svg(model, **{ dimension => value })
        end.to raise_error(Emfsvg::RenderError, /finite and positive/)
      end
    end
  end

  it "rejects non-finite caller-model header coordinates before builder allocation" do
    [Float::NAN, Float::INFINITY].each do |coordinate|
      bounds = Struct.new(:left, :top, :right, :bottom).new(coordinate, 0, 100, 100)
      header = Struct.new(:bounds).new(bounds)
      metafile = Struct.new(:header).new(header)
      expect(Emfsvg::SvgBuilder).not_to receive(:new)
      expect { Emfsvg.to_svg(metafile) }.to raise_error(Emfsvg::RenderError, /Header coordinates must be finite/)
    end
  end

  it "rejects zero header spans before builder allocation or record materialization" do
    [[0, 0, 0, 100], [0, 0, 100, 0]].each do |bounds|
      malformed = bytes.dup
      malformed[8, 16] = bounds.pack("l<4")
      metafile = Emf.parse(malformed)
      expect(Emfsvg::SvgBuilder).not_to receive(:new)
      expect(metafile).not_to receive(:each)
      expect { Emfsvg.to_svg(metafile) }.to raise_error(Emfsvg::RenderError, /Header .*finite and positive/)
    end
  end

  it "rejects derived dimensions that overflow despite finite inputs" do
    malformed = bytes.dup
    malformed[8, 16] = [0, 0, 100, 1].pack("l<4")
    expect { Emfsvg.from_bytes(malformed, height: Float::MAX) }.to raise_error(Emfsvg::RenderError, /Output width/)
  end

  it "preserves exact SVG bytes for accepted dimensions" do
    expected = Emfsvg::SpecSupport::FixturePath.read_fixture("emfsvg_golden", "image1.svg")
    expect(Emfsvg.to_svg(model).b).to eq(expected.b)
  end

  it "preserves exact SVG bytes at the actual record ceiling" do
    stub_const("Emfsvg::Renderer::MAX_RECORDS", model.to_a.length)
    expected = Emfsvg::SpecSupport::FixturePath.read_fixture("emfsvg_golden", "image1.svg")
    expect(Emfsvg.to_svg(model).b).to eq(expected.b)
  end

  it "rejects actual records over the ceiling with typed local metadata" do
    stub_const("Emfsvg::Renderer::MAX_RECORDS", 2)
    expect do
      Emfsvg.to_svg(model)
    end.to raise_error(Emfsvg::ResourceLimitError) { |error|
      expect([error.resource, error.limit, error.actual, error.cause]).to eq([:records, 2, 3, nil])
    }
  end

  it "does not trust a caller-model header that understates the record count" do
    stub_const("Emfsvg::Renderer::MAX_RECORDS", 2)
    allow(model.header).to receive(:n_records).and_return(0)
    expect { Emfsvg.to_svg(model) }.to raise_error(Emfsvg::ResourceLimitError, /records limit exceeded/)
  end

  it "stops a lazy caller-model enumeration at the first excess record" do
    stub_const("Emfsvg::Renderer::MAX_RECORDS", 2)
    consumed = 0
    record = model.first
    records = Enumerator.new do |yielder|
      loop do
        consumed += 1
        raise "enumeration continued beyond the bound" if consumed > 3

        yielder << record
      end
    end
    metafile = Emf::Model::Metafile.new(format: model.format, header: model.header, records: records)
    expect do
      Emfsvg.to_svg(metafile)
    end.to raise_error(Emfsvg::ResourceLimitError) { |error|
      expect([error.resource, error.limit, error.actual]).to eq([:records, 2, 3])
    }
    expect(consumed).to eq(3)
  end

  it "preserves inverted header bounds with positive output dimensions" do
    malformed = bytes.dup
    malformed[8, 16] = [100, 100, 0, 0].pack("l<4")
    svg = Emfsvg.from_bytes(malformed, width: 50, height: 50)
    expect(svg).to include('width="50.0000" height="50.0000"')
    expect(svg).to include("translate(-50.0000, -50.0000)")
  end
end
