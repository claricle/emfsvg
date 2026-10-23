# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe "Public model projection" do
  let(:fixture_bytes) { Emfsvg::SpecSupport::FixturePath.read_fixture("image1.emf") }
  let(:header_bytes) { fixture_bytes.byteslice(0, fixture_bytes.unpack1("@4V")) }
  let(:rectangle_bytes) { [43, 24, 10, 20, 30, 40].pack("V2l<4") }
  let(:raw_bytes) { [0x12345678, 12, 0xAABBCCDD].pack("V*") }
  let(:eof_bytes) { [14, 20, 0, 0, 20].pack("V*") }
  let(:bytes) do
    result = header_bytes + rectangle_bytes + raw_bytes + eof_bytes
    result[48, 8] = [result.bytesize, 4].pack("V2")
    result
  end
  let(:metafile) { Emf.parse(bytes) }

  it "projects ordered typed payloads and preserves unknown Raw bytes" do
    expect(metafile).to be_a(Emf::Model::Metafile)
    records = metafile.to_a
    expect(records.map { |record| record.wire.class }).to eq([
                                                               Emf::Emr::Binary::Records::Rectangle,
                                                               Emf::Emr::Binary::Records::Raw,
                                                               Emf::Emr::Binary::Records::Eof
                                                             ])
    expect(records.first.wire.rcl_box.snapshot).to eq(left: 10, top: 20, right: 30, bottom: 40)
    expect(records[1].wire.to_binary_s).to eq(raw_bytes)
    expect(metafile.errors).to be_empty

    svg = Emfsvg.to_svg(metafile)
    expect(svg).to be_a(String)
    expect(svg).to include('<rect x="10.0000" y="20.0000" width="20.0000" height="20.0000"')
    expect(Emfsvg.from_bytes(bytes)).to eq(svg)
    expect(records[1].wire.to_binary_s).to eq(raw_bytes)
  end

  it "renders identical SVG through the file, bytes, and model boundaries" do
    Tempfile.create(["model-projection", ".emf"]) do |file|
      File.binwrite(file.path, bytes)
      expect(Emfsvg.from_file(file.path, width: 200)).to eq(Emfsvg.to_svg(metafile, width: 200))
    end
    expect(Emfsvg.from_bytes(bytes, width: 200)).to eq(Emfsvg.to_svg(metafile, width: 200))
  end

  it "preserves the existing fixture's exact rendering" do
    model = Emf.parse(fixture_bytes)
    expected = Emfsvg::Renderer.call(model, Emfsvg::Options.new)
    expect(Emfsvg.from_bytes(fixture_bytes)).to eq(expected)
    expect(Emfsvg.from_file(Emfsvg::SpecSupport::FixturePath.fixture("image1.emf"))).to eq(expected)
    expect(Emfsvg.to_svg(model)).to eq(expected)
  end

  context "with an invalid variable-array record preserved as Raw" do
    let(:raw_bytes) { [3, 28, 0, 0, 10, 10, 2].pack("V2l<4V") }

    it "renders the valid records without treating legacy error text as a skipped-record diagnostic" do
      expect(metafile.errors).not_to be_empty
      expect(metafile.to_a[1].wire).to be_a(Emf::Emr::Binary::Records::Raw)
      expect(metafile.to_a[1].wire.to_binary_s).to eq(raw_bytes)
      expect { Emfsvg.to_svg(metafile) }.not_to output.to_stderr
      expect(Emfsvg.from_bytes(bytes)).to eq(Emfsvg.to_svg(metafile))
    end
  end

  it "translates unreadable bytes and preserves the upstream error as cause" do
    expect { Emfsvg.from_bytes("invalid EMF") }.to raise_error(Emfsvg::ParseError) { |error|
      expect(error.cause).to be_a(Emf::FormatError)
      expect(error.message).to eq(error.cause.message)
    }
  end

  it "translates fatal header failures from files with their cause" do
    Tempfile.create(["model-projection", ".emf"]) do |file|
      File.binwrite(file.path, fixture_bytes.byteslice(0, 44))
      expect { Emfsvg.from_file(file.path) }.to raise_error(Emfsvg::ParseError) { |error|
        expect(error.cause).to be_a(Emf::FormatError)
        expect(error.message).to include("truncated EMF header")
      }
    end
  end

  it "propagates invalid renderer options after parsing" do
    expect { Emfsvg.from_bytes(bytes, unsupported_option: true) }.to raise_error(ArgumentError, /unknown keyword/)
  end

  it "propagates input type errors without classifying them as parse failures" do
    expect { Emfsvg.from_bytes(nil) }.to raise_error(NoMethodError)
  end
end
