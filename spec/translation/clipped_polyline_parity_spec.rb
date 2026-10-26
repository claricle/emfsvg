# frozen_string_literal: true

require "spec_helper"

RSpec.describe "canonical clipped Polyline parity" do
  let(:fixture) { File.read(File.expand_path("../fixtures/golden/test-001.svg", __dir__)) }
  let(:path) do
    fixture.lines.find do |line|
      line.start_with?("<path  clip-path=") && line.include?('stroke-linejoin="round" fill=')
    end.strip
  end
  let(:clip_id) { path[/clip-path="url\(#([^)]+)\)"/, 1] }
  let(:definition) { fixture.scan(%r{<defs>.*?</defs>}).find { |entry| entry.include?(%(id="#{clip_id}")) } }
  let(:svg) { %(#{fixture.lines.first(3).join}#{definition}\n#{path}\n</g>\n</svg>\n) }
  let(:bytes) { Emfsvg.from_svg(svg) }
  let(:parsed) { Emf.parse(bytes) }
  let(:records) { parsed.records.map(&:wire) }
  let(:output) { Emfsvg.from_bytes(bytes) }

  it "preserves the corpus-001 clipped drawing operation and exact path spelling" do
    expect(parsed.errors).to be_empty
    expect(records.grep(Emf::Emr::Binary::Records::Polyline).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::LineTo)).to be_empty
    rendered_path = output.lines.find { |line| line.start_with?("<path  clip-path=") }.strip
    rendered_id = rendered_path[/clip-path="url\(#([^)]+)\)"/, 1]

    expect(output).to include(%(<clipPath id="#{rendered_id}">))
    expect(rendered_path.sub(rendered_id, clip_id)).to eq(path)
  end

  it "renders the emitted clipped wire identically with the pinned C reference", :live_reference do
    require "tempfile"
    Tempfile.create(["clipped-polyline", ".emf"]) do |file|
      file.binmode
      file.write(bytes)
      file.flush

      expect(Emfsvg::Compat.generate_reference(file.path)).to eq(output)
    end
  end

  [
    ['stroke-linejoin="round" fill=', 'stroke-linejoin="round"  fill='],
    ["<path  clip-path=", "<path clip-path="],
    ['stroke="#FFFFFF" stroke-width="1px"', 'stroke-width="1px" stroke="#FFFFFF"'],
    ["M 54.9538,333.0372", "M 54.95380,333.0372"]
  ].each do |before, after|
    context "with noncanonical spelling #{after.inspect}" do
      let(:path) { super().sub(before, after) }

      it "preserves the existing LineTo strategy and clipping" do
        expect(parsed.errors).to be_empty
        expect(records.grep(Emf::Emr::Binary::Records::LineTo).size).to eq(1)
        expect(records.grep(Emf::Emr::Binary::Records::Polyline)).to be_empty
        expect(output).to include('<path  clip-path="url(#clip-')
      end
    end
  end

  context "with an ordinary SVG clip identifier" do
    let(:svg) { super().gsub(clip_id, "plot") }

    it "keeps the existing LineTo strategy" do
      expect(records.grep(Emf::Emr::Binary::Records::LineTo).size).to eq(1)
      expect(records.grep(Emf::Emr::Binary::Records::Polyline)).to be_empty
    end
  end
end
