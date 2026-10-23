# frozen_string_literal: true

require "spec_helper"
require "emfsvg/visitors"

RSpec.describe "Invalid UTF-16 text encoding" do
  let(:fixture_bytes) { Emfsvg::SpecSupport::FixturePath.read_fixture("image1.emf") }
  let(:header_bytes) { fixture_bytes.byteslice(0, fixture_bytes.unpack1("@4V")) }
  let(:text_bytes) { [0xDF54, 0x0042].pack("v*") }
  let(:text_char_count) { text_bytes.bytesize / 2 }
  let(:text_record_size) { (76 + text_bytes.bytesize + 3) / 4 * 4 }
  let(:expected_following_text) { "B" }
  let(:text_record) do
    [[84, text_record_size, 0, 0, 10, 10, text_char_count].pack("V2l<4V"), [1.0, 1.0].pack("e2"),
     [0, 0, text_char_count, 76, 0, 0, 0, 10, 10, 0].pack("l<2V3l<4V"), text_bytes,
     "\0" * (text_record_size - 76 - text_bytes.bytesize)].join
  end
  let(:bytes) do
    result = header_bytes + text_record + [14, 20, 0, 0, 20].pack("V*")
    result[48, 8] = [result.bytesize, 3].pack("V2")
    result
  end

  shared_examples "a recoverable damaged text record" do
    [false, true].product(%i[from_bytes to_svg]).each do |verbose, boundary|
      it "recovers through #{boundary} with verbose=#{verbose} and preserves following text" do
        input = boundary == :from_bytes ? bytes : Emf.parse(bytes)
        rendered = nil
        expect { rendered = Emfsvg.public_send(boundary, input, verbose: verbose) }
          .not_to output.to_stderr
        expect(rendered).to include("<![CDATA[?#{expected_following_text}]]>")
      end
    end
  end

  context "with an EXTTEXTOUTW lone low surrogate" do
    include_examples "a recoverable damaged text record"
  end

  context "with an EXTTEXTOUTW lone high surrogate" do
    let(:text_bytes) { [0xD800, 0x0043].pack("v*") }
    let(:expected_following_text) { "C" }

    include_examples "a recoverable damaged text record"
  end

  context "with a SMALLTEXTOUT lone low surrogate" do
    let(:text_record_size) { (36 + text_bytes.bytesize + 3) / 4 * 4 }
    let(:text_record) do
      [[108, text_record_size, 0, 0, text_char_count, 0x100, 1].pack("V2l<2V3"), [1.0, 1.0].pack("e2"),
       text_bytes, "\0" * (text_record_size - 36 - text_bytes.bytesize)].join
    end

    include_examples "a recoverable damaged text record"
  end

  it "classifies an odd UTF-16 byte sequence in a supplied wire record" do
    visitor = Emfsvg::Visitors::EmrVisitor.new(
      Emfsvg::SvgBuilder.new, Emfsvg::DeviceContext.new, Emfsvg::ObjectTable.new,
      Emfsvg::TransformStack.new, nil, false, Emfsvg::Options.new
    )
    wire = Struct.new(:off_string, :n_chars, :f_options, :to_binary_s).new(2, 1, 0, "\0\0A")

    expect(visitor.send(:ext_text_content, wire, utf16: true)).to eq("?")
  end

  context "with valid UTF-16LE text" do
    let(:text_bytes) { [0x0041, 0xD83D, 0xDE00].pack("v*") }

    it "preserves valid text and a non-BMP surrogate pair" do
      expect(Emfsvg.from_bytes(bytes)).to include("<![CDATA[A😀]]>")
    end
  end
end
