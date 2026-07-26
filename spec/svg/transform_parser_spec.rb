# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::Svg::TransformParser do
  let(:identity) { Emf::Model::Geometry::Matrix.identity }

  describe ".parse" do
    it "returns identity for nil/empty" do
      expect(described_class.parse(nil)).to eq(identity)
      expect(described_class.parse("")).to eq(identity)
    end

    it "parses translate(x, y)" do
      m = described_class.parse("translate(10, 20)")
      expect([m.dx, m.dy]).to eq([10.0, 20.0])
    end

    it "parses translate(x) with y=0 default" do
      m = described_class.parse("translate(15)")
      expect([m.dx, m.dy]).to eq([15.0, 0.0])
    end

    it "parses scale(s)" do
      m = described_class.parse("scale(2)")
      expect([m.m11, m.m22]).to eq([2.0, 2.0])
    end

    it "parses scale(sx, sy)" do
      m = described_class.parse("scale(2, 3)")
      expect([m.m11, m.m22]).to eq([2.0, 3.0])
    end

    it "parses rotate(angle)" do
      m = described_class.parse("rotate(90)")
      expect(m.m11).to be_within(0.0001).of(0.0)
      expect(m.m12).to be_within(0.0001).of(1.0)
      expect(m.m21).to be_within(0.0001).of(-1.0)
      expect(m.m22).to be_within(0.0001).of(0.0)
    end

    it "parses rotate around a centre" do
      m = described_class.parse("rotate(90, 10, 20)")
      expect(m.dx).to be_within(0.0001).of(30.0)
      expect(m.dy).to be_within(0.0001).of(10.0)
    end

    it "parses matrix(a,b,c,d,e,f)" do
      m = described_class.parse("matrix(1, 2, 3, 4, 5, 6)")
      expect([m.m11, m.m12, m.m21, m.m22, m.dx, m.dy]).to eq([1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
    end

    it "composes left-to-right" do
      # translate(10,0) scale(2): the scale is applied first to local
      # coords, then the translate moves the result.
      m = described_class.parse("translate(10, 0) scale(2)")
      point = transform_point(m, 5, 0)
      expect(point).to eq([20.0, 0.0])
    end

    it "raises FormatError for unknown functions" do
      expect { described_class.parse("frobnicate(1, 2)") }.to raise_error(Emfsvg::FormatError)
    end
  end

  def transform_point(matrix, x, y)
    [
      (matrix.m11 * x) + (matrix.m21 * y) + matrix.dx,
      (matrix.m12 * x) + (matrix.m22 * y) + matrix.dy
    ]
  end
end
