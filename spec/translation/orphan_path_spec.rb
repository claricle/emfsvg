# frozen_string_literal: true

require "spec_helper"

RSpec.describe "canonical orphan and empty stroked paths" do
  def source(path)
    %(<svg xmlns="http://www.w3.org/2000/svg" width="30" height="30">#{path}</svg>)
  end

  def path(data)
    [
      %(<path d="#{data}" stroke="#000000" stroke-width="1.0000" ),
      %( stroke-linecap="round"  stroke-linejoin="round" fill="none" />)
    ].join
  end

  it "preserves an initial LineTo and separate figures through real EMF records" do
    original = path("L 2.0000,3.0000 M 4.0000,5.0000 L 6.0000,7.0000 ")
    bytes = Emfsvg.from_svg(source(original))
    parsed = Emf.parse(bytes)
    expect(parsed.errors).to be_empty
    records = parsed.records.map(&:wire)
    drawing = records.select do |record|
      [Emf::Emr::Binary::Records::MoveToEx, Emf::Emr::Binary::Records::LineTo].any? { |type| record.is_a?(type) }
    end

    expected = [Emf::Emr::Binary::Records::LineTo, Emf::Emr::Binary::Records::MoveToEx,
                Emf::Emr::Binary::Records::LineTo]
    expect(drawing.map(&:class)).to eq(expected)
    expect(records.grep(Emf::Emr::Binary::Records::StrokePath).size).to eq(1)
    expect(Emfsvg.from_bytes(bytes)).to include(original)
  end

  it "retains a canonical empty stroked path" do
    original = path("")
    bytes = Emfsvg.from_svg(source(original))
    parsed = Emf.parse(bytes)
    expect(parsed.errors).to be_empty
    records = parsed.records.map(&:wire)

    expect(records.grep(Emf::Emr::Binary::Records::BeginPath).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::EndPath).size).to eq(1)
    expect(records.grep(Emf::Emr::Binary::Records::StrokePath).size).to eq(1)
    expect(Emfsvg.from_bytes(bytes)).to include(original)
  end

  it "keeps ordinary noncanonical orphan paths normalized from the origin" do
    original = path("L 2,3 M 4,5 L 6,7 ")
    bytes = Emfsvg.from_svg(source(original))
    expect(Emf.parse(bytes).errors).to be_empty
    expect(Emfsvg.from_bytes(bytes)).to include('d="M 0.0000,0.0000 L 2.0000,3.0000 ')
  end

  it "requires canonical attribute spacing before retaining a leading LineTo" do
    original = path("L 2.0000,3.0000 M 4.0000,5.0000 L 6.0000,7.0000 ")
               .sub('fill="none" />', 'fill="none"/>')
    bytes = Emfsvg.from_svg(source(original))
    expect(Emf.parse(bytes).errors).to be_empty
    expect(Emfsvg.from_bytes(bytes)).to include('d="M 0.0000,0.0000 L 2.0000,3.0000 ')
  end

  it "keeps ordinary empty paths omitted when attribute spelling differs" do
    original = path("").sub('fill="none" />', 'fill="none"/>')
    bytes = Emfsvg.from_svg(source(original))
    expect(Emf.parse(bytes).errors).to be_empty
    expect(Emfsvg.from_bytes(bytes)).not_to include("<path ")
  end
end
