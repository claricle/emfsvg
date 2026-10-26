# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe "Public resource limits" do
  let(:fixture_bytes) { Emfsvg::SpecSupport::FixturePath.read_fixture("image1.emf") }
  let(:overflow_metadata) { [:input_bytes, fixture_bytes.bytesize - 1, fixture_bytes.bytesize] }

  it "loads the resource error with immutable metadata readers" do
    error = Emfsvg::ResourceLimitError.new(resource: :input_bytes, limit: 10, actual: 11)

    expect(error).to be_a(Emfsvg::Error)
    expect([error.resource, error.limit, error.actual]).to eq([:input_bytes, 10, 11])
    expect(error.message).to include("input_bytes", "10", "11")
    expect { error.resource = :output_bytes }.to raise_error(NoMethodError)
    expect { error.limit = 20 }.to raise_error(NoMethodError)
    expect { error.actual = 20 }.to raise_error(NoMethodError)
  end

  it "rejects oversized bytes before calling the parser" do
    stub_const("Emf::Emr::Parser::MAX_INPUT_BYTES", fixture_bytes.bytesize - 1)
    expect(Emf).not_to receive(:parse)

    expect { Emfsvg.from_bytes(fixture_bytes) }.to raise_error(Emfsvg::ResourceLimitError) { |error|
      expect([error.resource, error.limit, error.actual]).to eq(overflow_metadata)
      expect(error.cause).to be_nil
    }
  end

  it "rejects oversized files before reading them" do
    stub_const("Emf::Emr::Parser::MAX_INPUT_BYTES", fixture_bytes.bytesize - 1)
    Tempfile.create(["resource-limit", ".emf"]) do |file|
      File.binwrite(file.path, fixture_bytes)
      expect(File).not_to receive(:binread).with(file.path)
      expect(Emf).not_to receive(:parse)

      expect { Emfsvg.from_file(file.path) }.to raise_error(Emfsvg::ResourceLimitError) { |error|
        expect([error.resource, error.limit, error.actual]).to eq(overflow_metadata)
      }
    end
  end

  it "checks the bytes again when a file grows after its size check" do
    stub_const("Emf::Emr::Parser::MAX_INPUT_BYTES", fixture_bytes.bytesize - 1)
    Tempfile.create(["resource-limit", ".emf"]) do |file|
      File.binwrite(file.path, fixture_bytes)
      allow(File).to receive(:size).with(file.path).and_return(fixture_bytes.bytesize - 1)
      expect(Emf).not_to receive(:parse)

      expect { Emfsvg.from_file(file.path) }.to raise_error(Emfsvg::ResourceLimitError) { |error|
        expect([error.resource, error.limit, error.actual]).to eq(overflow_metadata)
      }
    end
  end

  it "preserves missing-file errors" do
    Tempfile.create(["resource-limit", ".emf"]) do |file|
      file.close
      File.unlink(file.path)
      expect { Emfsvg.from_file(file.path) }.to raise_error(Errno::ENOENT)
    end
  end

  it "accepts exact-limit bytes and files without changing their rendering" do
    expected = Emfsvg.from_bytes(fixture_bytes, width: 200)
    stub_const("Emf::Emr::Parser::MAX_INPUT_BYTES", fixture_bytes.bytesize)

    expect(Emfsvg.from_bytes(fixture_bytes, width: 200)).to eq(expected)
    Tempfile.create(["resource-limit", ".emf"]) do |file|
      File.binwrite(file.path, fixture_bytes)
      expect(Emfsvg.from_file(file.path, width: 200)).to eq(expected)
    end
  end

  it "retains unreadable-input translation and its upstream cause" do
    expect { Emfsvg.from_bytes("invalid EMF") }.to raise_error(Emfsvg::ParseError) { |error|
      expect(error.cause).to be_a(Emf::FormatError)
      expect(error.message).to eq(error.cause.message)
    }
  end

  it "propagates unexpected backend failures without reclassifying them" do
    failure = RuntimeError.new("backend failure")
    allow(Emf).to receive(:parse).and_raise(failure)

    expect { Emfsvg.from_bytes(fixture_bytes) }.to raise_error(RuntimeError) { |error|
      expect(error).to equal(failure)
    }
  end
end
