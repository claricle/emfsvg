# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Canonical title clip scopes" do
  it "preserves every byte of test-056 including intermediate viewport definitions" do
    source = File.binread(File.expand_path("../fixtures/emfsvg_golden/test-056.svg", __dir__))
    bytes = Emfsvg.from_svg(source)
    expect(Emf.parse(bytes).errors).to be_empty
    expect(Emfsvg.from_bytes(bytes).b).to eq(source)
  end

  it "preserves the fractional viewport and all three title scopes of test-060" do
    source = File.binread(File.expand_path("../fixtures/emfsvg_golden/test-060.svg", __dir__))
    output = Emfsvg.from_bytes(Emfsvg.from_svg(source)).b
    expect(output.lines.first(16)).to eq(source.lines.first(16))
  end

  it "restores the empty native clip before preserving unused definitions" do
    source = File.binread(File.expand_path("../fixtures/emfsvg_golden/test-056.svg", __dir__))
    records = Emf.parse(Emfsvg.from_svg(source)).records.map(&:wire)
    stack = []
    clip = nil
    text_clips = []
    records.each do |wire|
      case wire
      when Emf::Emr::Binary::Records::SaveDc then stack << clip
      when Emf::Emr::Binary::Records::RestoreDc then clip = stack.pop
      when Emf::Emr::Binary::Records::IntersectClipRect then clip = wire.rcl_clip.snapshot
      when Emf::Emr::Binary::Records::ExtSelectClipRgn
        expect([wire.cb_rgn_data.to_i, wire.dw_mode.to_i]).to eq([0, 5])
        expect(stack.size).to eq(0)
        clip = nil
      when Emf::Emr::Binary::Records::ExtTextOutW then text_clips << clip
      end
    end
    expect(stack).to be_empty
    expect(clip).to be_nil
    expect(text_clips.first(2)).to eq([
                                        { left: 1_460_000, top: 80_000, right: 4_790_000, bottom: 250_000 },
                                        { left: 1_390_000, top: 270_000, right: 4_860_000, bottom: 440_000 }
                                      ])
    expect(records.grep(Emf::Emr::Binary::Records::ExtSelectClipRgn).size).to eq(2)
  end

  [[:ordinary_id, ->(source) { source.sub("clip-16807", "ordinary").sub("url(#clip-16807)", "url(#ordinary)") }],
   [:ordinary_spelling, ->(source) { source.sub('Z Z" />', 'Z Z"/>') }]].each do |name, change|
    it "keeps the conservative guard for #{name} referenced clips" do
      source = File.binread(File.expand_path("../fixtures/emfsvg_golden/test-056.svg", __dir__))
      records = Emf.parse(Emfsvg.from_svg(change.call(source))).records.map(&:wire)
      expect(records.grep(Emf::Emr::Binary::Records::ExtSelectClipRgn)).to be_empty
    end
  end
end
