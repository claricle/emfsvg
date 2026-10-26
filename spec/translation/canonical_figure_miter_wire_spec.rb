# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe "canonical stroked cubic figure miter payloads" do
  let(:source) { File.read("spec/fixtures/emfsvg_golden/test-186.svg") }
  let(:paths) do
    source.lines.grep(/<path /).select { |line| line.include?('stroke-miterlimit="10.0000"') }.map(&:strip)
  end
  let(:path) { paths.fetch(0) }
  let(:svg) { %(<svg xmlns="http://www.w3.org/2000/svg" width="14030" height="9920">#{path}</svg>) }
  let(:bytes) { Emfsvg.from_svg(svg) }
  let(:records) { Emf.parse(bytes).records.map(&:wire) }
  let(:miter) { records.grep(Emf::Emr::Binary::Records::SetMiterLimit).first }

  [0, 1, 2].each do |index|
    context "with original cubic figure #{index + 1}" do
      let(:path) { paths.fetch(index) }

      it "preserves the original path and the legacy integer wire contract" do
        expect(records.grep(Emf::Emr::Binary::Records::StrokePath).size).to eq(1)
        expect(miter.to_binary_s.byteslice(8, 4).unpack1("V")).to eq(10)
        expect(Emfsvg.from_bytes(bytes)).to include(path)
      end

      it "matches pinned C on fresh serialized bytes", :live_reference do
        Tempfile.create(["canonical-figure-miter", ".emf"]) do |file|
          file.binmode
          file.write(bytes)
          file.flush
          reference = Emfsvg::Compat.generate_reference(file.path)
          expect(reference).to include(path)
          expect(reference).to eq(Emfsvg.from_bytes(bytes))
        end
      end
    end
  end

  context "with ordinary SVG attribute spacing" do
    let(:path) { super().sub("  stroke-linecap=", " stroke-linecap=") }

    it "keeps the float payload" do
      expect(miter.to_binary_s.byteslice(8, 4)).to eq([10.0].pack("e"))
      expect(Emfsvg.from_bytes(bytes)).to include('stroke-miterlimit="10.0000"')
    end
  end

  ["10.5000", "8388608.0000", "0.0000", "-1.0000"].each do |limit|
    context "with a nonrepresentable legacy limit of #{limit}" do
      let(:path) { super().sub('stroke-miterlimit="10.0000"', %(stroke-miterlimit="#{limit}")) }

      it "retains the float payload without rounding or overflow" do
        expect(miter.to_binary_s.byteslice(8, 4)).to eq([limit.to_f].pack("e"))
      end
    end
  end
end
