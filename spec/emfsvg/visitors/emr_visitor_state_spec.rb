# frozen_string_literal: true

require "spec_helper"
require "emfsvg/visitors"

# Records reach the visitor with BinData primitives for every field. The
# visitor compares device-context state against integer constants for each
# drawn point (map mode, brush style, ...), and each comparison on a BinData
# value is routed through BinData::Base#==. These specs pin that every
# state-setting handler stores a plain Integer, and that rendering with the
# unwrapped state is identical to rendering with raw Integers.
RSpec.describe Emfsvg::Visitors::EmrVisitor do
  def u32(value) = BinData::Uint32le.new(value)
  def s32(value) = BinData::Int32le.new(value)

  def build_visitor(dc: Emfsvg::DeviceContext.new)
    described_class.new(
      Emfsvg::SvgBuilder.new, dc, Emfsvg::ObjectTable.new,
      Emfsvg::TransformStack.new, nil, false, Emfsvg::Options.new
    )
  end

  let(:dc) { Emfsvg::DeviceContext.new }
  let(:visitor) { build_visitor(dc: dc) }
  let(:point) { Struct.new(:x, :y) }
  let(:size) { Struct.new(:cx, :cy) }

  describe "device context state" do
    {
      visit_set_map_mode: [{ map_mode: 8 }, :map_mode, 8],
      visit_set_bk_mode: [{ bk_mode: 2 }, :bk_mode, 2],
      visit_set_poly_fill_mode: [{ poly_fill_mode: 2 }, :poly_fill_mode, 2],
      visit_set_text_align: [{ text_align_mode: 24 }, :text_align, 24],
      visit_set_stretch_blt_mode: [{ stretch_mode: 3 }, :stretch_mode, 3]
    }.each do |handler, (fields, reader, expected)|
      it "#{handler} stores a plain Integer" do
        wire = Struct.new(*fields.keys).new(*fields.values.map { |v| u32(v) })
        visitor.public_send(handler, wire)

        expect(dc.public_send(reader)).to eq(expected)
        expect(dc.public_send(reader)).to be_an(Integer)
      end
    end

    {
      visit_set_window_org_ex: %i[origin window_org],
      visit_set_viewport_org_ex: %i[origin viewport_org]
    }.each do |handler, (field, reader)|
      it "#{handler} stores plain Integers" do
        wire = Struct.new(field).new(point.new(s32(-5), s32(7)))
        visitor.public_send(handler, wire)

        expect(dc.public_send(reader)).to eq([-5, 7])
        expect(dc.public_send(reader)).to all(be_an(Integer))
      end
    end

    {
      visit_set_window_ext_ex: :window_ext,
      visit_set_viewport_ext_ex: :viewport_ext
    }.each do |handler, reader|
      it "#{handler} stores plain Integers" do
        wire = Struct.new(:extent).new(size.new(s32(300), s32(-200)))
        visitor.public_send(handler, wire)

        expect(dc.public_send(reader)).to eq([300, -200])
        expect(dc.public_send(reader)).to all(be_an(Integer))
      end
    end

    it "keeps the origin applied for isotropic and anisotropic modes only" do
      visitor.visit_set_map_mode(Struct.new(:map_mode).new(u32(8)))
      expect(visitor.use_orgs?).to be(true)
      visitor.visit_set_map_mode(Struct.new(:map_mode).new(u32(1)))
      expect(visitor.use_orgs?).to be(false)
    end
  end

  describe "object table" do
    it "stores a corrupt high pen handle without allocating intervening slots" do
      # bad_corrupted_2014-12-13-133727.emf, raw record 6152 (CREATEPEN).
      wire = Struct.new(:ih_pen, :pen_style, :width, :color)
                   .new(u32(0x8900_0001), u32(0), point.new(s32(17), s32(0)),
                        Struct.new(:red, :green, :blue, :reserved).new(255, 0, 0, 0))

      visitor.visit_create_pen(wire)

      table = visitor.instance_variable_get(:@object_table)
      expect(table.size).to eq(1)
      expect(table.lookup(0x8900_0001).object.width).to eq(17)
      visitor.visit_delete_object(Struct.new(:ih_object).new(u32(0x8900_0001)))
      expect(table.size).to eq(0)
    end

    it "stores pen and brush fields as plain Integers" do
      pen_wire = Struct.new(:ih_pen, :pen_style, :width, :color)
                       .new(u32(2), u32(0), point.new(s32(3), s32(0)),
                            Struct.new(:red, :green, :blue, :reserved).new(1, 2, 3, 0))
      visitor.visit_create_pen(pen_wire)
      brush_wire = Struct.new(:ih_brush, :brush_style, :brush_hatch, :color)
                         .new(u32(3), u32(0), u32(0),
                              Struct.new(:red, :green, :blue, :reserved).new(1, 2, 3, 0))
      visitor.visit_create_brush_indirect(brush_wire)

      table = visitor.instance_variable_get(:@object_table)
      pen = table.lookup(2).object
      brush = table.lookup(3).object
      expect([pen.style, pen.width, brush.style, brush.hatch]).to all(be_an(Integer))
    end
  end

  describe "rendering" do
    def render_polygon(coords)
      visitor = build_visitor
      pts = coords.map { |x, y| point.new(BinData::Int16le.new(x), BinData::Int16le.new(y)) }
      visitor.visit_polygon16(Struct.new(:apts).new(pts))
      visitor.instance_variable_get(:@builder).out.dup
    end

    it "emits the same bytes for BinData and Integer coordinates" do
      pts = [[10, 20], [-30, 40], [50, -60]]
      raw = build_visitor
      raw.visit_polygon16(Struct.new(:apts).new(pts.map { |x, y| point.new(x, y) }))

      expect(render_polygon(pts)).to eq(raw.instance_variable_get(:@builder).out)
    end
  end
end
