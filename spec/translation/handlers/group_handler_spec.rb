# frozen_string_literal: true

require "spec_helper"
require "leptris"

RSpec.describe Emfsvg::Translation::Handlers::GroupHandler do
  let(:context) { Emfsvg::Translation::Context.new }

  it "emits SaveDC at start and RestoreDC(-1) at end" do
    element = Emfsvg::Svg::Element.from_node(
      Leptris::XML.parse("<g><rect width=\"10\" height=\"10\"/></g>").root
    )
    described_class.call(element, context)
    wire_classes = context.records.map { |r| r.wire.class }
    expect(wire_classes.first).to eq(Emf::Emr::Binary::Records::SaveDc)
    expect(wire_classes.last).to eq(Emf::Emr::Binary::Records::RestoreDc)
    expect(context.records.last.wire.saved_dc).to eq(-1)
  end

  it "emits SetWorldTransform when transform= is present" do
    element = Emfsvg::Svg::Element.from_node(
      Leptris::XML.parse('<g transform="translate(10, 20)"><rect/></g>').root
    )
    described_class.call(element, context)
    swt = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::SetWorldTransform) }
    expect(swt).not_to be_nil
    expect(swt.wire.xform.dx).to eq(10.0)
    expect(swt.wire.xform.dy).to eq(20.0)
  end

  it "always emits SetWorldTransform (even for identity) so the group wrapper round-trips" do
    element = Emfsvg::Svg::Element.from_node(
      Leptris::XML.parse("<g><rect/></g>").root
    )
    described_class.call(element, context)
    swt = context.records.find { |r| r.wire.is_a?(Emf::Emr::Binary::Records::SetWorldTransform) }
    expect(swt).not_to be_nil
  end

  it "dispatches child elements between SaveDC and RestoreDC" do
    element = Emfsvg::Svg::Element.from_node(
      Leptris::XML.parse("<g><rect/><ellipse/></g>").root
    )
    described_class.call(element, context)
    # SaveDC, then rect/ellipse handler records, then RestoreDC
    expect(context.records.first.wire).to be_a(Emf::Emr::Binary::Records::SaveDc)
    expect(context.records.last.wire).to be_a(Emf::Emr::Binary::Records::RestoreDc)
    # Inner records should include Rectangle and Ellipse
    inner = context.records[1..-2]
    expect(inner.any? { |r| r.wire.is_a?(Emf::Emr::Binary::Records::Rectangle) }).to be true
    expect(inner.any? { |r| r.wire.is_a?(Emf::Emr::Binary::Records::Ellipse) }).to be true
  end
end
