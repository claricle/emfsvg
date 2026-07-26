# frozen_string_literal: true

require "spec_helper"
require "nokogiri"

RSpec.describe Emfsvg::SvgMatcher, ".flatten_transform_groups" do
  def parse(svg)
    doc = Nokogiri::XML(svg, &:noblanks)
    doc.remove_namespaces!
    doc
  end

  it "unwraps <g transform=M><X/></g> to <X transform=M/>" do
    doc = parse("<svg><g transform=\"translate(10,20)\"><rect/></g></svg>")
    described_class.flatten_transform_groups(doc.root)
    rect = doc.root.element_children.first
    expect(rect.name).to eq("rect")
    expect(rect["transform"]).to eq("translate(10,20)")
  end

  it "composes nested transforms when unwrapping" do
    doc = parse("<svg><g transform=\"translate(10,0)\"><rect transform=\"scale(2)\"/></g></svg>")
    described_class.flatten_transform_groups(doc.root)
    rect = doc.root.element_children.first
    expect(rect.name).to eq("rect")
    # The composed transform should be matrix form (translate(10,0) * scale(2))
    expect(rect["transform"]).to start_with("matrix(")
  end

  it "preserves g elements with multiple children" do
    doc = parse("<svg><g transform=\"translate(10,0)\"><rect/><ellipse/></g></svg>")
    described_class.flatten_transform_groups(doc.root)
    g = doc.root.element_children.first
    expect(g.name).to eq("g")
    expect(g.element_children.size).to eq(2)
  end

  it "preserves g elements without transform" do
    doc = parse("<svg><g><rect/></g></svg>")
    described_class.flatten_transform_groups(doc.root)
    g = doc.root.element_children.first
    expect(g.name).to eq("g")
  end

  it "handles deeply nested single-child groups" do
    doc = parse("<svg><g transform=\"translate(1,0)\"><g transform=\"scale(2)\"><rect/></g></g></svg>")
    described_class.flatten_transform_groups(doc.root)
    rect = doc.root.element_children.first
    expect(rect.name).to eq("rect")
    expect(rect["transform"]).to start_with("matrix(")
  end
end

RSpec.describe Emfsvg::SvgMatcher, ".compose_transforms" do
  it "returns nil for nil inputs" do
    expect(described_class.compose_transforms(nil, nil)).to be_nil
  end

  it "returns outer when inner is nil" do
    expect(described_class.compose_transforms("translate(5,0)", nil)).to eq("translate(5,0)")
  end

  it "returns inner when outer is nil" do
    expect(described_class.compose_transforms(nil, "scale(2)")).to eq("scale(2)")
  end

  it "composes two transforms into matrix form" do
    result = described_class.compose_transforms("translate(10,0)", "scale(2)")
    expect(result).to start_with("matrix(")
  end
end
