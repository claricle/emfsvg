# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::DeviceContext do
  it "initialises with default pen, brush, and identity matrix" do
    dc = described_class.new
    expect(dc.pen).to be_a(Emfsvg::Pen)
    expect(dc.brush).to be_a(Emfsvg::Brush)
    expect(dc.world_transform).to be_identity
    expect(dc.text_color).to eq(Emf::Model::Geometry::Color.black)
  end

  it "dup produces an independent copy" do
    dc = described_class.new
    dc.text_color = Emf::Model::Geometry::Color.white
    other = dc.dup
    other.text_color = Emf::Model::Geometry::Color.black
    expect(dc.text_color).to eq(Emf::Model::Geometry::Color.white)
    expect(other.text_color).to eq(Emf::Model::Geometry::Color.black)
  end
end

RSpec.describe Emfsvg::Pen do
  it "is null when style is NULL" do
    pen = described_class.new(style: described_class::NULL)
    expect(pen).to be_null
  end

  it "is not null for solid style" do
    pen = described_class.new(style: described_class::SOLID)
    expect(pen).not_to be_null
  end
end

RSpec.describe Emfsvg::Brush do
  it "is null when style is NULL" do
    brush = described_class.new(style: described_class::NULL)
    expect(brush).to be_null
  end
end

RSpec.describe Emfsvg::ObjectTable do
  it "stores and looks up by 1-based index" do
    table = described_class.new
    pen = Emfsvg::Pen.new
    table.store(3, :pen, pen)
    expect(table.lookup(3).object).to be(pen)
  end

  it "removes entries on delete" do
    table = described_class.new
    table.store(1, :pen, Emfsvg::Pen.new)
    table.delete(1)
    expect(table.lookup(1)).to be_nil
  end
end

RSpec.describe Emfsvg::TransformStack do
  it "pushes snapshots and restores by negative offset" do
    stack = described_class.new
    dc1 = Emfsvg::DeviceContext.new
    dc1.text_color = Emf::Model::Geometry::Color.white
    dc2 = Emfsvg::DeviceContext.new
    dc2.text_color = Emf::Model::Geometry::Color.new(red: 255, green: 0, blue: 0)
    stack.push(dc1)
    stack.push(dc2)
    # RestoreDC(-1) restores the most recently saved state (top of stack).
    # This mirrors libemf2svg's restoreDeviceContext which walks the stack
    # starting at the top for negative indices.
    restored = stack.restore(-1)
    expect(restored.text_color).to eq(Emf::Model::Geometry::Color.new(red: 255, green: 0, blue: 0))
  end
end
