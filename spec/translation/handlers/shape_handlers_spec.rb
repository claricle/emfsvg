# frozen_string_literal: true

require "spec_helper"
require "nokogiri"

RSpec.describe Emfsvg::Translation::Handlers::RectHandler do
  let(:context) { Emfsvg::Translation::Context.new }

  def rect_node(attrs)
    attrs_str = attrs.map { |k, v| %(#{k}="#{v}") }.join(" ")
    Emfsvg::Svg::Element.from_node(
      Nokogiri::XML("<rect #{attrs_str}/>").root
    )
  end

  it "emits CreatePen + SelectObject + CreateBrushIndirect + SelectObject + Rectangle + Deletes" do
    element = rect_node("x" => "10", "y" => "20", "width" => "100", "height" => "50",
                        "fill" => "#FF0000", "stroke" => "#0000FF")
    described_class.call(element, context)

    wire_classes = context.records.map { |r| r.wire.class }
    expect(wire_classes).to eq([
                                 Emf::Emr::Binary::Records::CreatePen,
                                 Emf::Emr::Binary::Records::SelectObject,
                                 Emf::Emr::Binary::Records::CreateBrushIndirect,
                                 Emf::Emr::Binary::Records::SelectObject,
                                 Emf::Emr::Binary::Records::Rectangle,
                                 Emf::Emr::Binary::Records::DeleteObject,
                                 Emf::Emr::Binary::Records::DeleteObject
                               ])
  end

  it "uses RoundRect when rx/ry present" do
    element = rect_node("x" => "0", "y" => "0", "width" => "80", "height" => "40",
                        "rx" => "5", "ry" => "5")
    described_class.call(element, context)
    expect(context.records.map { |r| r.wire.class }).to include(Emf::Emr::Binary::Records::RoundRect)
  end

  it "emits Rectangle with bounds matching x/y/width/height" do
    element = rect_node("x" => "10", "y" => "20", "width" => "100", "height" => "50")
    described_class.call(element, context)
    rect_record = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::Rectangle) }
    box = rect_record.wire.rcl_box
    expect([box.left, box.top, box.right, box.bottom]).to eq([10, 20, 110, 70])
  end
end

RSpec.describe Emfsvg::Translation::Handlers::EllipseHandler do
  it "emits Ellipse with bounds cx-rx, cy-ry, cx+rx, cy+ry" do
    context = Emfsvg::Translation::Context.new
    element = Emfsvg::Svg::Element.from_node(
      Nokogiri::XML('<ellipse cx="50" cy="40" rx="20" ry="10"/>').root
    )
    described_class.call(element, context)
    ellipse = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::Ellipse) }
    box = ellipse.wire.rcl_box
    expect([box.left, box.top, box.right, box.bottom]).to eq([30, 30, 70, 50])
  end
end

RSpec.describe Emfsvg::Translation::Handlers::CircleHandler do
  it "delegates to EllipseHandler with rx=ry=r" do
    context = Emfsvg::Translation::Context.new
    element = Emfsvg::Svg::Element.from_node(
      Nokogiri::XML('<circle cx="50" cy="50" r="25"/>').root
    )
    described_class.call(element, context)
    ellipse = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::Ellipse) }
    expect(ellipse).not_to be_nil
    box = ellipse.wire.rcl_box
    expect([box.left, box.top, box.right, box.bottom]).to eq([25, 25, 75, 75])
  end
end

RSpec.describe Emfsvg::Translation::Handlers::LineHandler do
  it "emits MoveToEx then LineTo" do
    context = Emfsvg::Translation::Context.new
    element = Emfsvg::Svg::Element.from_node(
      Nokogiri::XML('<line x1="0" y1="0" x2="100" y2="50"/>').root
    )
    described_class.call(element, context)
    move = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::MoveToEx) }
    line = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::LineTo) }
    expect([move.wire.origin.x, move.wire.origin.y]).to eq([0, 0])
    expect([line.wire.origin.x, line.wire.origin.y]).to eq([100, 50])
  end
end

RSpec.describe Emfsvg::Translation::Handlers::PolylineHandler do
  it "emits a Polyline record with the points" do
    context = Emfsvg::Translation::Context.new
    element = Emfsvg::Svg::Element.from_node(
      Nokogiri::XML('<polyline points="0,0 100,0 100,100"/>').root
    )
    described_class.call(element, context)
    poly = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::Polyline) }
    expect(poly.wire.cptl).to eq(3)
    expect(poly.wire.aptl.map { |p| [p.x, p.y] }).to eq([[0, 0], [100, 0], [100, 100]])
  end
end

RSpec.describe Emfsvg::Translation::Handlers::PolygonHandler do
  it "emits a Polygon record (closed)" do
    context = Emfsvg::Translation::Context.new
    element = Emfsvg::Svg::Element.from_node(
      Nokogiri::XML('<polygon points="0,0 100,0 100,100"/>').root
    )
    described_class.call(element, context)
    poly = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::Polygon) }
    expect(poly.wire.cptl).to eq(3)
  end
end

RSpec.describe Emfsvg::Translation::Handlers::PathHandler do
  it "emits a Polyline for an M/L-only path" do
    context = Emfsvg::Translation::Context.new
    element = Emfsvg::Svg::Element.from_node(
      Nokogiri::XML(%(<path d="M 0 0 L 100 0 L 100 100"/>)).root
    )
    described_class.call(element, context)
    poly = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::Polyline) }
    expect(poly).not_to be_nil
    expect(poly.wire.cptl).to eq(3)
  end

  it "emits a Polygon for a closed M/L/Z path" do
    context = Emfsvg::Translation::Context.new
    element = Emfsvg::Svg::Element.from_node(
      Nokogiri::XML(%(<path d="M 0 0 L 100 0 L 100 100 Z"/>)).root
    )
    described_class.call(element, context)
    poly = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::Polygon) }
    expect(poly).not_to be_nil
  end

  it "emits a PolyBezier when cubic C commands present" do
    context = Emfsvg::Translation::Context.new
    element = Emfsvg::Svg::Element.from_node(
      Nokogiri::XML(%(<path d="M 0 0 C 10 10 20 20 30 30"/>)).root
    )
    described_class.call(element, context)
    bezier = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::PolyBezier) }
    expect(bezier).not_to be_nil
    # 4 points: starting + 3 cubic control/end
    expect(bezier.wire.cptl).to eq(4)
  end
end
