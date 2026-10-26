# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe "canonical PolylineTo miter wire payloads" do
  let(:fixture_name) { "test-039" }
  let(:path) { File.readlines("spec/fixtures/emfsvg_golden/#{fixture_name}.svg").fetch(28).strip }
  let(:svg) { %(<svg xmlns="http://www.w3.org/2000/svg" width="14030" height="9920">#{path}</svg>) }
  let(:bytes) { Emfsvg.from_svg(svg) }
  let(:records) { Emf.parse(bytes).records.map(&:wire) }
  let(:miter) { records.grep(Emf::Emr::Binary::Records::SetMiterLimit).first }
  let(:output) { Emfsvg.from_bytes(bytes) }

  shared_examples "an integer miter payload" do
    it "serializes the legacy integer contract and preserves the source path" do
      expect(records.grep(Emf::Emr::Binary::Records::PolylineTo).size).to eq(1)
      expect(miter.to_binary_s.byteslice(8, 4).unpack1("V")).to eq(8)
      expect(output).to include(path)
    end

    it "matches pinned C on the actual freshly serialized bytes", :live_reference do
      Tempfile.create(["canonical-miter-wire", ".emf"]) do |file|
        file.binmode
        file.write(bytes)
        file.flush

        reference = Emfsvg::Compat.generate_reference(file.path)
        expect(reference).to include(path)
        expect(reference).to eq(output)
      end
    end
  end

  include_examples "an integer miter payload"

  context "with original fixture 040" do
    let(:fixture_name) { "test-040" }

    include_examples "an integer miter payload"
  end

  context "with ordinary SVG spelling" do
    let(:path) { super().sub("  fill=", " fill=") }

    it "retains the generic float payload and rendered miter limit" do
      expect(records.grep(Emf::Emr::Binary::Records::PolylineTo)).to be_empty
      expect(miter.miter_limit).to eq(8.0)
      expect(miter.to_binary_s.byteslice(8, 4)).to eq([8.0].pack("e"))
      expect(output).to include('stroke-miterlimit="8.0000"')
    end
  end

  ["1.0000", "5.0000", "8388607.0000"].each do |limit|
    context "with a representable legacy limit of #{limit}" do
      let(:path) { super().sub('stroke-miterlimit="8.0000"', %(stroke-miterlimit="#{limit}")) }

      it "preserves the integer payload and rendered limit at the reader boundaries" do
        expect(miter.to_binary_s.byteslice(8, 4).unpack1("V")).to eq(limit.to_i)
        expect(output).to include(path)
      end
    end
  end

  ["8.5000", "8388608.0000", "0.0000", "-1.0000"].each do |limit|
    context "with a nonrepresentable legacy limit of #{limit}" do
      let(:path) { super().sub('stroke-miterlimit="8.0000"', %(stroke-miterlimit="#{limit}")) }

      it "preserves its float payload without truncation or integer overflow" do
        expect(records.grep(Emf::Emr::Binary::Records::PolylineTo).size).to eq(1)
        expect(miter.to_binary_s.byteslice(8, 4)).to eq([limit.to_f].pack("e"))
        expect(output).to include(%(stroke-miterlimit="#{limit}"))
      end
    end
  end
end
