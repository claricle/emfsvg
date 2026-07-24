# frozen_string_literal: true

require "emf"

module Emfsvg
  module Visitors
    # Walks Emf::Model::Emr::Records::WireAdapter records and dispatches
    # by underlying wire class to handler methods.
    #
    # WireAdapter is emf's catch-all. Each wire class corresponds to a
    # visit_<class_name_in_snake_case> method here. Adding a handler:
    # 1. Write the method (e.g. `visit_polygon`).
    # 2. Register it in HANDLERS map keyed by the wire class.
    class EmrVisitor < Emf::Model::Visitor
      # Maps wire class -> handler method name (as symbol).
      HANDLERS = {
        Emf::Emr::Binary::Records::Eof => :visit_eof,
        Emf::Emr::Binary::Records::SetTextColor => :visit_set_text_color,
        Emf::Emr::Binary::Records::SetBkColor => :visit_set_bk_color,
        Emf::Emr::Binary::Records::SetBkMode => :visit_set_bk_mode,
        Emf::Emr::Binary::Records::SetMapMode => :visit_set_map_mode,
        Emf::Emr::Binary::Records::SetRop2 => :visit_set_rop2,
        Emf::Emr::Binary::Records::SetPolyFillMode => :visit_set_poly_fill_mode,
        Emf::Emr::Binary::Records::SetTextAlign => :visit_set_text_align,
        Emf::Emr::Binary::Records::SetStretchBltMode => :visit_set_stretch_blt_mode,
        Emf::Emr::Binary::Records::SaveDc => :visit_save_dc,
        Emf::Emr::Binary::Records::RestoreDc => :visit_restore_dc,
        Emf::Emr::Binary::Records::SelectObject => :visit_select_object,
        Emf::Emr::Binary::Records::DeleteObject => :visit_delete_object,
        Emf::Emr::Binary::Records::CreatePen => :visit_create_pen,
        Emf::Emr::Binary::Records::CreateBrushIndirect => :visit_create_brush_indirect,
        Emf::Emr::Binary::Records::SetWindowOrgEx => :visit_set_window_org_ex,
        Emf::Emr::Binary::Records::SetWindowExtEx => :visit_set_window_ext_ex,
        Emf::Emr::Binary::Records::SetViewportOrgEx => :visit_set_viewport_org_ex,
        Emf::Emr::Binary::Records::SetViewportExtEx => :visit_set_viewport_ext_ex,
        Emf::Emr::Binary::Records::MoveToEx => :visit_move_to_ex,
        Emf::Emr::Binary::Records::LineTo => :visit_line_to,
        Emf::Emr::Binary::Records::Rectangle => :visit_rectangle,
        Emf::Emr::Binary::Records::Ellipse => :visit_ellipse,
        Emf::Emr::Binary::Records::RoundRect => :visit_round_rect,
        Emf::Emr::Binary::Records::Arc => :visit_arc,
        Emf::Emr::Binary::Records::ArcTo => :visit_arc,
        Emf::Emr::Binary::Records::Chord => :visit_arc,
        Emf::Emr::Binary::Records::Pie => :visit_arc,
        Emf::Emr::Binary::Records::Polygon => :visit_polygon,
        Emf::Emr::Binary::Records::Polyline => :visit_polyline,
        Emf::Emr::Binary::Records::Polygon16 => :visit_polygon16,
        Emf::Emr::Binary::Records::Polyline16 => :visit_polyline16,
        Emf::Emr::Binary::Records::PolyBezier => :visit_poly_bezier,
        Emf::Emr::Binary::Records::PolyBezier16 => :visit_poly_bezier16,
        Emf::Emr::Binary::Records::PolyBezierTo => :visit_poly_bezier,
        Emf::Emr::Binary::Records::PolyBezierTo16 => :visit_poly_bezier16,
        Emf::Emr::Binary::Records::PolylineTo => :visit_polyline,
        Emf::Emr::Binary::Records::PolylineTo16 => :visit_polyline16,
        Emf::Emr::Binary::Records::BeginPath => :visit_begin_path,
        Emf::Emr::Binary::Records::EndPath => :visit_end_path,
        Emf::Emr::Binary::Records::CloseFigure => :visit_close_figure,
        Emf::Emr::Binary::Records::FillPath => :visit_fill_path,
        Emf::Emr::Binary::Records::StrokePath => :visit_stroke_path,
        Emf::Emr::Binary::Records::StrokeAndFillPath => :visit_stroke_and_fill_path,
        Emf::Emr::Binary::Records::AbortPath => :visit_abort_path,
        Emf::Emr::Binary::Records::SetWorldTransform => :visit_set_world_transform,
        Emf::Emr::Binary::Records::ModifyWorldTransform => :visit_modify_world_transform,
        Emf::Emr::Binary::Records::SetMiterLimit => :visit_set_miter_limit,
        Emf::Emr::Binary::Records::Comment => :visit_comment
      }.freeze

      attr_reader :current_x, :current_y

      def initialize(builder, dc, object_table, transform_stack, bounds, fix_y, options)
        @builder = builder
        @dc = dc
        @object_table = object_table
        @transform_stack = transform_stack
        @bounds = bounds
        @fix_y = fix_y
        @options = options
        @current_x = 0
        @current_y = 0
        @path_d = nil
        @open_groups = 0
      end

      # The Emf wire-record-adapter calls this. Dispatch by wire class.
      def visit_emr_wire_record(adapter)
        wire = adapter.wire
        method_name = HANDLERS[wire.class]
        if method_name && respond_to?(method_name)
          send(method_name, wire)
        elsif @options.verbose
          warn "emfsvg: no handler for #{wire.class.name&.split('::')&.last}"
        end
      rescue StandardError => e
        raise unless @options.verbose

        warn "emfsvg: handler #{method_name} raised #{e.class}: #{e.message}"
      end

      def flush_open_groups
        @builder.raw("</g>" * @open_groups)
        @open_groups = 0
      end

      # --- Handlers ---

      def visit_eof(_wire); end

      def visit_set_text_color(wire)
        @dc.text_color = Emf::Model::Geometry::Color.from_wire(wire.color)
      end

      def visit_set_bk_color(wire)
        @dc.bk_color = Emf::Model::Geometry::Color.from_wire(wire.color)
      end

      def visit_set_bk_mode(wire)
        @dc.bk_mode = wire.bk_mode
      end

      def visit_set_map_mode(wire)
        @dc.map_mode = wire.map_mode
      end

      def visit_set_rop2(wire)
        # ROP2 mostly ignored by SVG (we are not a raster engine).
      end

      def visit_set_poly_fill_mode(wire)
        @dc.poly_fill_mode = wire.poly_fill_mode
      end

      def visit_set_text_align(wire)
        @dc.text_align = wire.text_align_mode
      end

      def visit_set_stretch_blt_mode(wire)
        @dc.stretch_mode = wire.stretch_mode
      end

      def visit_save_dc(_wire)
        @transform_stack.push(@dc)
      end

      def visit_restore_dc(wire)
        @dc = @transform_stack.restore(wire.saved_dc) || @dc
      end

      def visit_select_object(wire)
        entry = @object_table.lookup(wire.ih_object)
        return unless entry

        case entry.type
        when :pen then @dc.pen = entry.object
        when :brush then @dc.brush = entry.object
        end
      end

      def visit_delete_object(wire)
        @object_table.delete(wire.ih_object)
      end

      def visit_create_pen(wire)
        pen = Pen.new(
          style: wire.pen_style,
          width: wire.width.x,
          color: Emf::Model::Geometry::Color.from_wire(wire.color)
        )
        @object_table.store(wire.ih_pen, :pen, pen)
      end

      def visit_create_brush_indirect(wire)
        brush = Brush.new(
          style: wire.brush_style,
          color: Emf::Model::Geometry::Color.from_wire(wire.color),
          hatch: wire.brush_hatch
        )
        @object_table.store(wire.ih_brush, :brush, brush)
      end

      def visit_set_window_org_ex(_wire); end

      def visit_set_window_ext_ex(_wire); end

      def visit_set_viewport_org_ex(_wire); end

      def visit_set_viewport_ext_ex(_wire); end

      def visit_move_to_ex(wire)
        @current_x = wire.origin.x
        @current_y = wire.origin.y
      end

      def visit_line_to(wire)
        attrs = stroke_attrs.merge(
          "x1" => @current_x, "y1" => maybe_flip_y(@current_y),
          "x2" => wire.origin.x, "y2" => maybe_flip_y(wire.origin.y)
        )
        @builder.tag("line", attrs, single: true)
        @current_x = wire.origin.x
        @current_y = wire.origin.y
      end

      def visit_rectangle(wire)
        l = wire.rcl_box.left
        t = wire.rcl_box.top
        r = wire.rcl_box.right
        b = wire.rcl_box.bottom
        attrs = fill_attrs.merge(stroke_attrs).merge(
          "x" => l, "y" => maybe_flip_y(t),
          "width" => r - l, "height" => b - t
        )
        @builder.tag("rect", attrs, single: true)
      end

      def visit_ellipse(wire)
        l = wire.rcl_box.left
        t = wire.rcl_box.top
        r = wire.rcl_box.right
        b = wire.rcl_box.bottom
        cx = (l + r) / 2.0
        cy = (t + b) / 2.0
        rx = (r - l) / 2.0
        ry = (b - t) / 2.0
        attrs = fill_attrs.merge(stroke_attrs).merge(
          "cx" => cx, "cy" => maybe_flip_y(cy),
          "rx" => rx, "ry" => ry
        )
        @builder.tag("ellipse", attrs, single: true)
      end

      def visit_round_rect(wire)
        l = wire.rcl_box.left
        t = wire.rcl_box.top
        r = wire.rcl_box.right
        b = wire.rcl_box.bottom
        rx = wire.szl_corner.cx / 2.0
        ry = wire.szl_corner.cy / 2.0
        attrs = fill_attrs.merge(stroke_attrs).merge(
          "x" => l, "y" => maybe_flip_y(t),
          "width" => r - l, "height" => b - t,
          "rx" => rx, "ry" => ry
        )
        @builder.tag("rect", attrs, single: true)
      end

      # TODO: arc/chord/pie arc reconstruction
      def visit_arc(wire); end

      def visit_polygon(wire)
        emit_path_polygon(wire.aptl.to_a, closed: true)
      end

      def visit_polyline(wire)
        emit_path_polygon(wire.aptl.to_a, closed: false)
      end

      def visit_polygon16(wire)
        emit_path_polygon(wire.apts.to_a, closed: true)
      end

      def visit_polyline16(wire)
        emit_path_polygon(wire.apts.to_a, closed: false)
      end

      # TODO: bezier curve reconstruction
      def visit_poly_bezier(wire); end

      def visit_poly_bezier16(wire); end

      def visit_begin_path(_wire)
        @path_d = +""
      end

      def visit_end_path(_wire)
        @path_d = nil
      end

      def visit_close_figure(_wire)
        @path_d&.<<("Z ")
      end

      def visit_fill_path(_wire)
        return unless @path_d && !@path_d.empty?

        attrs = fill_attrs.merge("d" => @path_d, "fill-rule" => fill_rule_attr)
        @builder.tag("path", attrs, single: true)
        @path_d = nil
      end

      def visit_stroke_path(_wire)
        return unless @path_d && !@path_d.empty?

        attrs = stroke_attrs.merge("d" => @path_d)
        @builder.tag("path", attrs, single: true)
        @path_d = nil
      end

      def visit_stroke_and_fill_path(_wire)
        return unless @path_d && !@path_d.empty?

        attrs = fill_attrs.merge(stroke_attrs).merge("d" => @path_d, "fill-rule" => fill_rule_attr)
        @builder.tag("path", attrs, single: true)
        @path_d = nil
      end

      def visit_abort_path(_wire)
        @path_d = nil
      end

      def visit_set_world_transform(wire)
        @dc.world_transform = Emf::Model::Geometry::Matrix.from_wire(wire.xform)
        emit_transform_group(@dc.world_transform)
      end

      def visit_modify_world_transform(wire)
        xform = Emf::Model::Geometry::Matrix.from_wire(wire.xform)
        @dc.world_transform = case wire.modify_mode
                              when 1 # MWT_IDENTITY
                                Emf::Model::Geometry::Matrix.identity
                              when 2 # MWT_LEFT_MULTIPLY
                                multiply_matrix(xform, @dc.world_transform)
                              when 3 # MWT_RIGHT_MULTIPLY
                                multiply_matrix(@dc.world_transform, xform)
                              else
                                xform
                              end
        emit_transform_group(@dc.world_transform)
      end

      def visit_set_miter_limit(wire)
        @dc.miter_limit = wire.miter_limit
      end

      def visit_comment(_wire); end

      private

      def emit_path_polygon(points, closed:)
        return if points.empty?

        d = +""
        d << "M #{points.first.x} #{maybe_flip_y(points.first.y)} "
        points[1..].each { |p| d << "L #{p.x} #{maybe_flip_y(p.y)} " }
        d << "Z " if closed
        attrs = (closed ? fill_attrs.merge(stroke_attrs) : stroke_attrs).merge("d" => d)
        attrs["fill-rule"] = fill_rule_attr if closed
        @builder.tag("path", attrs, single: true)
      end

      def fill_attrs
        brush = @dc.brush
        brush.null? ? { "fill" => "none" } : { "fill" => brush.color.to_hex }
      end

      def stroke_attrs
        pen = @dc.pen
        return { "stroke" => "none" } if pen.null?

        attrs = { "stroke" => pen.color.to_hex, "stroke-width" => pen.width }
        case pen.style
        when Pen::DASH
          attrs["stroke-dasharray"] = "4 2"
        when Pen::DOT
          attrs["stroke-dasharray"] = "1 2"
        when Pen::DASHDOT
          attrs["stroke-dasharray"] = "4 2 1 2"
        when Pen::DASHDOTDOT
          attrs["stroke-dasharray"] = "4 2 1 2 1 2"
        end
        attrs
      end

      def fill_rule_attr
        @dc.poly_fill_mode == 2 ? "nonzero" : "evenodd"
      end

      def maybe_flip_y(y)
        return y unless @fix_y

        # Wine/Sparx Y-repair: invert the Y anchor for the offending span.
        # This is a per-coordinate heuristic; the C library does it
        # selectively based on the bounding box. For now, mirror Y around
        # the bounds centre.
        centre = (@bounds.top + @bounds.bottom) / 2.0
        (2 * centre) - y
      end

      def emit_transform_group(matrix)
        attrs = {
          "transform" => format("matrix(%f %f %f %f %f %f)",
                                matrix.m11, matrix.m12,
                                matrix.m21, matrix.m22,
                                maybe_flip_y(matrix.dy) - matrix.dy + matrix.dy,
                                matrix.dy)
        }
        @builder.tag("g", attrs)
        @open_groups += 1
      end

      def multiply_matrix(a, b)
        Emf::Model::Geometry::Matrix.new(
          m11: (a.m11 * b.m11) + (a.m12 * b.m21),
          m12: (a.m11 * b.m12) + (a.m12 * b.m22),
          m21: (a.m21 * b.m11) + (a.m22 * b.m21),
          m22: (a.m21 * b.m12) + (a.m22 * b.m22),
          dx: (a.dx * b.m11) + (a.dy * b.m21) + b.dx,
          dy: (a.dx * b.m12) + (a.dy * b.m22) + b.dy
        )
      end
    end
  end
end
