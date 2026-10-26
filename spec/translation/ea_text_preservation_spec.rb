# frozen_string_literal: true

RSpec.describe "canonical empty text preservation" do
  let(:empty_text_svg) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="100" height="50">
        <text x="4" y="20" font-family="Carlito" font-size="10"><![CDATA[]]></text>
        <text x="5" y="20" font-family="Arial" font-size="10"></text>
        <text x="6" y="20" font-family="Arial" font-size="10">visible</text>
      </svg>
    SVG
  end

  it "round-trips an explicit empty CDATA text node while skipping an ordinary empty node" do
    bytes = Emfsvg.from_svg(empty_text_svg)
    parsed = Emf.parse(bytes)
    text_records = parsed.records.map(&:wire).grep(Emf::Emr::Binary::Records::ExtTextOutW)
    output = Emfsvg.from_bytes(bytes)

    expect(parsed.errors).to be_empty
    expect(text_records.map(&:n_chars)).to eq([0, 7])
    expect(output.scan("<![CDATA[]]>").length).to eq(1)
    expect(output).to include("<![CDATA[visible]]>")
  end

  %w[002 004 011 015 030 031].each do |number|
    it "preserves empty text records in C-rendered EA-test-file-#{number}" do
      path = File.join("spec/fixtures/emfsvg_golden", "EA-test-file-#{number}.svg")
      source = File.read(path)
      expected_empty = source.scan("<![CDATA[]]>").length
      bytes = Emfsvg.from_svg(source)
      parsed = Emf.parse(bytes)
      records = parsed.records.map(&:wire).grep(Emf::Emr::Binary::Records::ExtTextOutW)
      empty_records = records.count { |record| record.n_chars.zero? }
      output = Emfsvg.from_bytes(bytes)

      expect(parsed.errors).to be_empty
      expect(expected_empty).to be_positive
      expect(empty_records).to eq(expected_empty)
      expect(output.scan("<![CDATA[]]>").length).to eq(expected_empty)
    end
  end
end
