# frozen_string_literal: true

require "spec_helper"
require "leptris"

RSpec.describe Emfsvg::Translation::Handlers::RectHandler do
  let(:context) { Emfsvg::Translation::Context.new }

  def rect_node(attrs)
    attrs_str = attrs.map { |k, v| %(#{k}="#{v}") }.join(" ")
    Emfsvg::Svg::Element.from_node(
      Leptris::XML.parse("<rect #{attrs_str}/>").root
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
      Leptris::XML.parse('<ellipse cx="50" cy="40" rx="20" ry="10"/>').root
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
      Leptris::XML.parse('<circle cx="50" cy="50" r="25"/>').root
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
      Leptris::XML.parse('<line x1="0" y1="0" x2="100" y2="50"/>').root
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
      Leptris::XML.parse('<polyline points="0,0 100,0 100,100"/>').root
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
      Leptris::XML.parse('<polygon points="0,0 100,0 100,100"/>').root
    )
    described_class.call(element, context)
    poly = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::Polygon) }
    expect(poly.wire.cptl).to eq(3)
  end
end

RSpec.describe Emfsvg::Translation::Handlers::PathHandler do
  context "when round-tripping separate figures" do
    let(:svg) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <path d="#{data}" fill="red" stroke="blue"/>
        </svg>
      SVG
    end
    let(:rendered_svg) { Emfsvg.from_bytes(Emfsvg.from_svg(svg)) }
    let(:rendered_paths) { rendered_svg.scan(/<path\b[^>]*\bd="([^"]*)"/).flatten }
    let(:commands) { Emfsvg::Svg::PathData::Parser.parse(rendered_paths.first) }

    context "with closed contours" do
      let(:data) { "M 0 0 L 100 0 L 100 100 Z M 20 20 L 20 40 L 40 40 Z" }

      it "preserves contour boundaries and every coordinate in one compound path" do
        expect(rendered_paths.size).to eq(1)
        expect(commands.map(&:letter)).to eq(%w[M L L Z M L L Z])
        expect(commands.map(&:args)).to eq([[0, 0], [100, 0], [100, 100], [], [20, 20], [20, 40], [40, 40], []])
      end
    end

    context "with a single closed contour" do
      let(:data) { "M 0 0 H 100 V 100 Z" }

      it "preserves the existing polygon coordinates and closure" do
        expect(rendered_paths.size).to eq(1)
        expect(commands.map(&:letter)).to eq(%w[M L L Z])
        expect(commands.map(&:args)).to eq([[0, 0], [100, 0], [100, 100], []])
      end
    end

    context "with open contours" do
      let(:data) { "M 0 0 L 100 0 M 20 20 L 40 40" }

      it "preserves separate starts without closing or joining them" do
        expect(rendered_paths.size).to eq(1)
        expect(commands.map(&:letter)).to eq(%w[M L M L])
        expect(commands.map(&:args)).to eq([[0, 0], [100, 0], [20, 20], [40, 40]])
      end
    end

    context "with mixed closure and relative moves" do
      let(:data) { "M 10 10 L 30 10 L 30 30 Z m 40 40 l 20 0" }

      it "keeps closure local and resolves the relative move from the closed start" do
        expect(rendered_paths.size).to eq(1)
        expect(rendered_svg).to include('fill="#FF0000"', 'stroke="#0000FF"')
        expect(commands.map(&:letter)).to eq(%w[M L L Z M L])
        expect(commands.map(&:args)).to eq([[10, 10], [30, 10], [30, 30], [], [50, 50], [70, 50]])
      end
    end

    context "with cubic and line segments" do
      let(:data) { "M 0 0 C 10 10 20 20 30 30 L 40 30 Z M 50 50 c 10 0 20 10 30 20" }

      it "preserves both curve triples, line segments, starts and closure" do
        expect(rendered_paths.size).to eq(1)
        expect(commands.map(&:letter)).to eq(%w[M C L Z M C])
        expect(commands.map(&:args)).to eq([[0, 0], [10, 10, 20, 20, 30, 30], [40, 30], [],
                                            [50, 50], [60, 50, 70, 60, 80, 70]])
      end
    end
  end

  it "emits one PolyPolygon with separate point counts and scaled bounds" do
    context = Emfsvg::Translation::Context.new
    element = Emfsvg::Svg::Element.from_node(
      Leptris::XML.parse(%(<path d="M 0 0 L 100 0 L 100 100 Z M 20 20 L 20 40 L 40 40 Z"/>)).root
    )
    described_class.call(element, context)
    poly = context.records.find { |record| record.wire.is_a?(Emf::Emr::Binary::Records::PolyPolygon) }.wire
    expect(poly.n_polys).to eq(2)
    expect(poly.c_ptl_total).to eq(6)
    expect(poly.a_poly_counts.to_a).to eq([3, 3])
    expect(poly.aptl.map { |point| [point.x, point.y] }).to eq([[0, 0], [100, 0], [100, 100],
                                                                [20, 20], [20, 40], [40, 40]])
    expect([poly.rcl_bounds.left, poly.rcl_bounds.top, poly.rcl_bounds.right,
            poly.rcl_bounds.bottom]).to eq([0, 0, 100, 100])
  end

  it "emits a Polyline for an M/L-only path" do
    context = Emfsvg::Translation::Context.new
    element = Emfsvg::Svg::Element.from_node(
      Leptris::XML.parse(%(<path d="M 0 0 L 100 0 L 100 100"/>)).root
    )
    described_class.call(element, context)
    poly = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::Polyline) }
    expect(poly).not_to be_nil
    expect(poly.wire.cptl).to eq(3)
    expect(poly.wire.aptl.map { |point| [point.x, point.y] }).to eq([[0, 0], [100, 0], [100, 100]])
  end

  it "emits a Polygon for a closed M/L/Z path" do
    context = Emfsvg::Translation::Context.new
    element = Emfsvg::Svg::Element.from_node(
      Leptris::XML.parse(%(<path d="M 0 0 L 100 0 L 100 100 Z"/>)).root
    )
    described_class.call(element, context)
    poly = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::Polygon) }
    expect(poly).not_to be_nil
    expect(poly.wire.aptl.map { |point| [point.x, point.y] }).to eq([[0, 0], [100, 0], [100, 100]])
  end

  it "emits a PolyBezier when cubic C commands present" do
    context = Emfsvg::Translation::Context.new
    element = Emfsvg::Svg::Element.from_node(
      Leptris::XML.parse(%(<path d="M 0 0 C 10 10 20 20 30 30"/>)).root
    )
    described_class.call(element, context)
    bezier = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::PolyBezier) }
    expect(bezier).not_to be_nil
    # 4 points: starting + 3 cubic control/end
    expect(bezier.wire.cptl).to eq(4)
    expect(bezier.wire.aptl.map { |point| [point.x, point.y] }).to eq([[0, 0], [10, 10], [20, 20], [30, 30]])
  end
end
