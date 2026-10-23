# frozen_string_literal: true

require "spec_helper"
require "emfsvg/visitors"

RSpec.describe "Invalid UTF-16 text encoding" do
  let(:fixture_bytes) { Emfsvg::SpecSupport::FixturePath.read_fixture("image1.emf") }
  let(:header_bytes) { fixture_bytes.byteslice(0, fixture_bytes.unpack1("@4V")) }
  let(:text_bytes) { [0xDF54].pack("v") }
  let(:text_record) do
    [[84, 80, 0, 0, 10, 10, 1].pack("V2l<4V"), [1.0, 1.0].pack("e2"),
     [0, 0, 1, 76, 0, 0, 0, 10, 10, 0].pack("l<2V3l<4V"), text_bytes, "\0\0"].join
  end
  let(:bytes) do
    result = header_bytes + text_record + [14, 20, 0, 0, 20].pack("V*")
    result[48, 8] = [result.bytesize, 3].pack("V2")
    result
  end

  shared_examples "an invalid text record" do
    [false, true].product(%i[from_bytes to_svg]).each do |verbose, boundary|
      it "raises ParseError through #{boundary} with verbose=#{verbose} and preserves the encoding cause" do
        input = boundary == :from_bytes ? bytes : Emf.parse(bytes)
        expect do
          expect { Emfsvg.public_send(boundary, input, verbose: verbose) }
            .to raise_error(Emfsvg::ParseError) { |error|
              expect(error.cause).to be_a(Encoding::InvalidByteSequenceError)
              expect(error.message).to eq(error.cause.message)
            }
        end.not_to output.to_stderr
      end
    end
  end

  context "with an EXTTEXTOUTW lone low surrogate" do
    include_examples "an invalid text record"
  end

  context "with an EXTTEXTOUTW lone high surrogate" do
    let(:text_bytes) { [0xD800].pack("v") }

    include_examples "an invalid text record"
  end

  context "with a SMALLTEXTOUT lone low surrogate" do
    let(:text_record) do
      [[108, 40, 0, 0, 1, 0x100, 1].pack("V2l<2V3"), [1.0, 1.0].pack("e2"), text_bytes, "\0\0"].join
    end

    include_examples "an invalid text record"
  end

  it "classifies an odd UTF-16 byte sequence in a supplied wire record" do
    visitor = Emfsvg::Visitors::EmrVisitor.new(
      Emfsvg::SvgBuilder.new, Emfsvg::DeviceContext.new, Emfsvg::ObjectTable.new,
      Emfsvg::TransformStack.new, nil, false, Emfsvg::Options.new
    )
    wire = Struct.new(:off_string, :n_chars, :f_options, :to_binary_s).new(2, 1, 0, "\0\0A")

    expect { visitor.visit_ext_text_out_w(wire) }.to raise_error(Emfsvg::ParseError) { |error|
      expect(error.cause).to be_a(Encoding::InvalidByteSequenceError)
      expect(error.message).to eq(error.cause.message)
    }
  end

  context "with valid UTF-16LE text" do
    let(:text_bytes) { "A".encode("UTF-16LE").b }

    it "preserves the decoded text" do
      expect(Emfsvg.from_bytes(bytes)).to include("<![CDATA[A]]>")
    end
  end
end
