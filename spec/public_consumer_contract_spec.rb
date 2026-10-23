# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Public parser consumer contracts" do
  let(:bytes) { Emfsvg::SpecSupport::FixturePath.read_fixture("image1.emf") }
  let(:model) { Emf.parse(bytes) }
  let(:skipped) do
    [
      Emf::Model::Diagnostic.new(record_index: 9, record_code: 27, byte_offset: 180, disposition: :skipped),
      Emf::Model::Diagnostic.new(record_index: 2, record_code: 25, byte_offset: 120, disposition: :preserved_raw),
      Emf::Model::Diagnostic.new(record_index: 4, record_code: 0xBAADF00D, byte_offset: 140, disposition: :skipped)
    ].freeze
  end
  let(:warning) do
    "emfsvg: skipped EMF records: index=4,type=UNKNOWN(0xBAADF00D),code=3131961357,offset=140;" \
      "index=9,type=EMR_MOVETOEX,code=27,offset=180"
  end
  let(:upstream_error) { Emf::ResourceLimitError.new(resource: :work_units, limit: 10, actual: 11) }

  it "emits one sorted warning from immutable physical diagnostics and preserves exact SVG" do
    annotated = model.with_diagnostics(skipped)
    expected = Emfsvg.to_svg(model)
    expect(Kernel).to receive(:warn).with(warning).once
    expect(Emfsvg.to_svg(annotated)).to eq(expected)
    expect(annotated.diagnostics).to eq(skipped)
    expect(annotated.diagnostics.map(&:record_index)).to eq([9, 2, 4])
  end

  it "emits no skipped warning for clean models" do
    expect(Kernel).not_to receive(:warn)
    expect(Emfsvg.to_svg(model)).to be_a(String)
  end

  it "does not infer skipped records from errors or preserved Raw diagnostics" do
    annotated = Emf::Model::Metafile.new(format: model.format, header: model.header, records: model.records,
                                         errors: ["skipped record 9"], diagnostics: [skipped[1]])
    expect(Kernel).not_to receive(:warn)
    expect(Emfsvg.to_svg(annotated)).to eq(Emfsvg.to_svg(model))
  end

  it "warns only once through nested file and byte conversion boundaries" do
    allow(Emf).to receive(:parse).with(bytes).and_return(model.with_diagnostics(skipped))
    expect(Kernel).to receive(:warn).with(warning).once
    expect(Emfsvg.from_file(Emfsvg::SpecSupport::FixturePath.fixture("image1.emf"))).to be_a(String)
  end

  it "warns exactly for a physically skipped parser record" do
    header_size = bytes.unpack1("V", offset: 4)
    malformed = bytes.byteslice(0, header_size) + [27, 20].pack("V2")
    expect(Kernel).to receive(:warn).with(
      "emfsvg: skipped EMF records: index=1,type=EMR_MOVETOEX,code=27,offset=#{header_size}"
    ).once
    expect(Emfsvg.from_bytes(malformed)).to include("</svg>")
  end

  it "keeps a valid unknown Raw parser record silent" do
    header_size = bytes.unpack1("V", offset: 4)
    unknown = bytes.byteslice(0, header_size) + [0xBAADF00D, 8].pack("V2")
    parsed = Emf.parse(unknown)
    expect(parsed.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
    expect(Kernel).not_to receive(:warn)
    expect(Emfsvg.from_bytes(unknown)).to include("</svg>")
  end

  it "keeps actual preserved Raw recovery diagnostics silent" do
    header_size = bytes.unpack1("V", offset: 4)
    recovered = bytes.byteslice(0, header_size) + [3, 28].pack("V2") + [0, 0, 0, 0, 1].pack("l<5")
    parsed = Emf.parse(recovered)
    expect(parsed.diagnostics.map(&:disposition)).to eq([:preserved_raw])
    expect(parsed.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
    expect(Kernel).not_to receive(:warn)
    expect(Emfsvg.from_bytes(recovered)).to include("</svg>")
  end

  it "maps an actual upstream resource refusal from parsing with metadata and cause" do
    allow(Emf).to receive(:parse).and_raise(upstream_error)
    expect do
      Emfsvg.from_bytes(bytes)
    end.to raise_error(Emfsvg::ResourceLimitError) { |error|
      expect(error).to be_a(Emfsvg::Error)
      expect([error.resource, error.limit, error.actual]).to eq([:work_units, 10, 11])
      expect(error.cause).to equal(upstream_error)
    }
  end

  it "maps a real parser admission refusal without allocating a large input" do
    wmf = [1, 9, 0x300, 12, 0, 3, 0].pack("vvvVvVv") + [3, 0].pack("Vv")
    stub_const("Emf::Wmf::Binary::MAX_INPUT_BYTES", wmf.bytesize - 1)
    expect do
      Emfsvg.from_bytes(wmf)
    end.to raise_error(Emfsvg::ResourceLimitError) { |error|
      expect([error.resource, error.limit, error.actual]).to eq([:input_bytes, wmf.bytesize - 1, wmf.bytesize])
      expect(error.cause).to be_a(Emf::ResourceLimitError)
      expect([error.cause.resource, error.cause.limit, error.cause.actual]).to eq(
        [error.resource, error.limit, error.actual]
      )
    }
  end

  it "maps an upstream resource refusal during lazy model rendering" do
    allow(model).to receive(:each).and_raise(upstream_error)
    expect { Emfsvg.to_svg(model) }.to raise_error(Emfsvg::ResourceLimitError) { |error|
      expect([error.resource, error.limit, error.actual]).to eq([:work_units, 10, 11])
      expect(error.cause).to equal(upstream_error)
    }
  end

  it "keeps unreadable input as a parse error with its upstream cause" do
    expect { Emfsvg.from_bytes("unreadable") }.to raise_error(Emfsvg::ParseError) { |error|
      expect(error.cause).to be_a(Emf::FormatError)
    }
  end

  it "preserves unrelated upstream backend failures" do
    error = Emf::Error.new("backend unavailable")
    allow(Emf).to receive(:parse).and_raise(error)
    expect { Emfsvg.from_bytes(bytes) }.to(raise_error { |actual| expect(actual).to equal(error) })
  end

  it "preserves unrelated upstream failures during rendering" do
    error = Emf::FormatError.new("unrelated renderer failure")
    allow(model).to receive(:each).and_raise(error)
    expect { Emfsvg.to_svg(model) }.to(raise_error { |actual| expect(actual).to equal(error) })
  end
end
