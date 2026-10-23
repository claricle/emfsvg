# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::Translation::Context do
  let(:registry) { Emfsvg::Translation::HandlerRegistry.new }
  let(:context) { described_class.new(handler_registry: registry) }

  describe "#point_l" do
    it "returns a PointL with int32 x and y" do
      point = context.point_l(10, 20)
      expect(point.x).to eq(10)
      expect(point.y).to eq(20)
    end

    it "truncates decimals by default (Identity scaler)" do
      point = context.point_l(10.7, 20.3)
      expect(point.x).to eq(10)
      expect(point.y).to eq(20)
    end
  end

  describe "#rect_l" do
    it "returns a RectL with int32 bounds" do
      rect = context.rect_l(0, 0, 100, 50)
      expect(rect.left).to eq(0)
      expect(rect.right).to eq(100)
    end
  end

  describe "#size_l" do
    it "returns a SizeL with int32 cx and cy" do
      size = context.size_l(80, 40)
      expect(size.cx).to eq(80)
      expect(size.cy).to eq(40)
    end
  end

  describe "attribute-hash helpers" do
    it "return the same scaled values as the wire-object helpers" do
      scaled = described_class.new(handler_registry: registry,
                                   scaler: Emfsvg::Translation::Scaler::Fixed.new)
      expect(scaled.point_attrs(1.5, 2.5)).to eq(x: 15_000, y: 25_000)
      expect(scaled.rect_attrs(0, 1, 10.5, 5.25))
        .to eq(left: 0, top: 10_000, right: 105_000, bottom: 52_500)
      expect(scaled.size_attrs(80, 40)).to eq(cx: 800_000, cy: 400_000)
    end

    it "serialize identically when used as record fields" do
      klass = Emf::Emr::Binary::Records::Polygon
      common = { i_type: 3, cptl: 2 }
      from_objects = klass.new(**common, rcl_bounds: context.rect_l(0, 0, 9, 9),
                                         aptl: [context.point_l(1, 2), context.point_l(3, 4)])
      from_hashes = klass.new(**common, rcl_bounds: context.rect_attrs(0, 0, 9, 9),
                                        aptl: [context.point_attrs(1, 2), context.point_attrs(3, 4)])
      expect(from_hashes.to_binary_s).to eq(from_objects.to_binary_s)
    end
  end

  describe "#xform_wire_from" do
    it "returns the matrix wire form unchanged for Identity scaler" do
      matrix = Emf::Model::Geometry::Matrix.identity
      wire = context.xform_wire_from(matrix)
      expect(wire.m11).to eq(1.0)
      expect(wire.dx).to eq(0.0)
    end
  end

  describe "with Fixed scaler" do
    let(:scaler) { Emfsvg::Translation::Scaler::Fixed.new }
    let(:context) { described_class.new(handler_registry: registry, scaler: scaler) }

    it "scales point coords by 10000" do
      point = context.point_l(1.5, 2.5)
      expect(point.x).to eq(15_000)
      expect(point.y).to eq(25_000)
    end

    it "scales rect bounds by 10000" do
      rect = context.rect_l(0, 0, 10.5, 5.25)
      expect(rect.right).to eq(105_000)
      expect(rect.bottom).to eq(52_500)
    end

    it "scales xform dx/dy by factor but leaves m11/m22 unchanged" do
      matrix = Emf::Model::Geometry::Matrix.new(
        m11: 2.0, m12: 0.0, m21: 0.0, m22: 3.0,
        dx: 10.5, dy: 20.25
      )
      wire = context.xform_wire_from(matrix)
      expect(wire.m11).to eq(2.0)
      expect(wire.m22).to eq(3.0)
      expect(wire.dx).to eq(105_000.0)
      expect(wire.dy).to eq(202_500.0)
    end
  end
end
