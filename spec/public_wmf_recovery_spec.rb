# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Public WMF recovery boundaries" do
  let(:bytes) do
    # Size drift can be recovered only when the physical record stream is complete.
    [1, 9, 0x300, 0xFFFF_FFFF, 0, 7, 0].pack("v3VvVv") +
      [7, 0x041B, 1, 2, 3, 4].pack("Vvs<4") +
      [5, 0x0214, 5, 6].pack("Vvs<2") + [3, 0].pack("Vv")
  end

  context "when a record body is truncated despite recoverable header Size drift" do
    it "raises a downstream parse error retaining the upstream physical failure" do
      expect(Kernel).not_to receive(:warn)
      expect { Emfsvg.from_bytes(bytes.byteslice(0, 40)) }.to raise_error(Emfsvg::ParseError) { |error|
        expect(error.cause).to be_a(Emf::ParseError)
        expect(error.message).to eq(error.cause.message)
        expect(error.cause.offset).to eq(32)
        expect(error.cause.evidence.check).to eq(:record_length_invalid)
      }
    end
  end

  context "when EOF is missing despite recoverable header Size drift" do
    it "raises a downstream parse error instead of treating the missing EOF as header drift" do
      expect(Kernel).not_to receive(:warn)
      expect { Emfsvg.from_bytes(bytes.byteslice(0, bytes.bytesize - 6)) }.to raise_error(Emfsvg::ParseError) { |error|
        expect(error.cause).to be_a(Emf::ParseError)
        expect(error.message).to eq(error.cause.message)
        expect(error.cause.offset).to eq(42)
        expect(error.cause.evidence.check).to eq(:eof_missing)
      }
    end
  end
end
