# frozen_string_literal: true

RSpec.describe "empty text round-trip parity" do
  it "preserves an empty zero-size text record" do
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="100" height="50">
        <text x="0" y="0" font-family="Arial" font-size="0" fill="#000000"></text>
        <text x="2" y="20" font-family="Arial" font-size="12">visible</text>
      </svg>
    SVG

    bytes = Emfsvg.from_svg(svg)
    parsed = Emf.parse(bytes)
    output = Emfsvg.from_bytes(bytes)

    expect(parsed.errors).to be_empty
    expect(parsed.records.map(&:wire).count { |record| record.is_a?(Emf::Emr::Binary::Records::ExtTextOutW) }).to eq(2)
    expect(output.scan("<![CDATA[]]>").length).to eq(1)
    expect(output).to include("<![CDATA[visible]]>")
  end
end
