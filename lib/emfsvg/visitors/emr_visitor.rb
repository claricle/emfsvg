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
        Emf::Emr::Binary::Records::ArcTo => :visit_arc_to,
        Emf::Emr::Binary::Records::Chord => :visit_chord,
        Emf::Emr::Binary::Records::Pie => :visit_pie,
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
        Emf::Emr::Binary::Records::Comment => :visit_comment,
        Emf::Emr::Binary::Records::SetPixelV => :visit_set_pixel_v,
        Emf::Emr::Binary::Records::CreateFontIndirectW => :visit_create_font_indirect_w,
        Emf::Emr::Binary::Records::ExtTextOutW => :visit_ext_text_out_w,
        Emf::Emr::Binary::Records::ExtTextOutA => :visit_ext_text_out_a,
        Emf::Emr::Binary::Records::IntersectClipRect => :visit_intersect_clip_rect,
        Emf::Emr::Binary::Records::ExcludeClipRect => :visit_exclude_clip_rect,
        Emf::Emr::Binary::Records::SetBrushOrgEx => :visit_set_brush_org_ex,
        Emf::Emr::Binary::Records::SetMetArgn => :visit_set_met_argn,
        Emf::Emr::Binary::Records::OffsetClipRgn => :visit_offset_clip_rgn,
        Emf::Emr::Binary::Records::SetIcmMode => :visit_set_icm_mode,
        Emf::Emr::Binary::Records::SetLayout => :visit_set_layout,
        Emf::Emr::Binary::Records::ScaleViewportExtEx => :visit_scale_viewport_ext_ex,
        Emf::Emr::Binary::Records::ScaleWindowExtEx => :visit_scale_window_ext_ex,
        Emf::Emr::Binary::Records::SetMapperFlags => :visit_set_mapper_flags,
        Emf::Emr::Binary::Records::SetArcDirection => :visit_set_arc_direction,
        Emf::Emr::Binary::Records::RealizePalette => :visit_realize_palette,
        Emf::Emr::Binary::Records::SelectPalette => :visit_select_palette,
        Emf::Emr::Binary::Records::CreatePalette => :visit_create_palette,
        Emf::Emr::Binary::Records::ResizePalette => :visit_resize_palette,
        Emf::Emr::Binary::Records::SetPaletteEntries => :visit_set_palette_entries,
        Emf::Emr::Binary::Records::PolyPolygon => :visit_poly_polygon,
        Emf::Emr::Binary::Records::PolyPolygon16 => :visit_poly_polygon16,
        Emf::Emr::Binary::Records::PolyPolyline => :visit_poly_polyline,
        Emf::Emr::Binary::Records::PolyPolyline16 => :visit_poly_polyline16,
        Emf::Emr::Binary::Records::PolyDraw => :visit_poly_draw,
        Emf::Emr::Binary::Records::PolyDraw16 => :visit_poly_draw16,
        Emf::Emr::Binary::Records::AngleArc => :visit_angle_arc,
        Emf::Emr::Binary::Records::DrawEscape => :visit_draw_escape,
        Emf::Emr::Binary::Records::ExtEscape => :visit_ext_escape,
        Emf::Emr::Binary::Records::NamedEscape => :visit_named_escape,
        Emf::Emr::Binary::Records::SmallTextOut => :visit_small_text_out,
        Emf::Emr::Binary::Records::SetLinkedUfis => :visit_set_linked_ufis,
        Emf::Emr::Binary::Records::ForceUfiMapping => :visit_force_ufi_mapping,
        Emf::Emr::Binary::Records::ColorCorrectPalette => :visit_color_correct_palette,
        Emf::Emr::Binary::Records::SetIcmProfileA => :visit_set_icm_profile_a,
        Emf::Emr::Binary::Records::SetIcmProfileW => :visit_set_icm_profile_w,
        Emf::Emr::Binary::Records::ColorMatchToTargetW => :visit_color_match_to_target_w,
        Emf::Emr::Binary::Records::CreateColorspace => :visit_create_colorspace,
        Emf::Emr::Binary::Records::CreateColorspaceW => :visit_create_colorspace_w,
        Emf::Emr::Binary::Records::SetColorspace => :visit_set_colorspace,
        Emf::Emr::Binary::Records::DeleteColorspace => :visit_delete_colorspace,
        Emf::Emr::Binary::Records::GlsRecord => :visit_gls_record,
        Emf::Emr::Binary::Records::GlsBoundedRecord => :visit_gls_bounded_record,
        Emf::Emr::Binary::Records::PixelFormat => :visit_pixel_format,
        Emf::Emr::Binary::Records::PolyTextOutA => :visit_poly_text_out_a,
        Emf::Emr::Binary::Records::PolyTextOutW => :visit_poly_text_out_w,
        Emf::Emr::Binary::Records::SetTextJustification => :visit_set_text_justification,
        Emf::Emr::Binary::Records::CreateMonoBrush => :visit_create_mono_brush,
        Emf::Emr::Binary::Records::CreateDibPatternBrushPt => :visit_create_dib_pattern_brush_pt,
        Emf::Emr::Binary::Records::ExtCreatePen => :visit_ext_create_pen
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
        when :font then @dc.font = entry.object
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
      def visit_arc(wire)
        emit_arc(wire, mode: :arc)
      end

      def visit_arc_to(wire)
        emit_arc(wire, mode: :arc)
      end

      def visit_chord(wire)
        emit_arc(wire, mode: :chord)
      end

      def visit_pie(wire)
        emit_arc(wire, mode: :pie)
      end

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
      def visit_poly_bezier(wire)
        # PolyBezier: first point is start anchor; subsequent points in
        # groups of 3 (control1, control2, end). Each group is one cubic
        # Bezier segment.
        points = wire.aptl.to_a
        return if points.size < 4

        d = "M #{points.first.x} #{maybe_flip_y(points.first.y)} "
        points[1..].each_slice(3) do |ctrl1, ctrl2, endpt|
          next if [ctrl1, ctrl2, endpt].any?(&:nil?)

          d << "C #{ctrl1.x} #{maybe_flip_y(ctrl1.y)} "
          d << "#{ctrl2.x} #{maybe_flip_y(ctrl2.y)} "
          d << "#{endpt.x} #{maybe_flip_y(endpt.y)} "
        end
        attrs = stroke_attrs.merge("fill" => "none", "d" => d)
        @builder.tag("path", attrs, single: true)
        @current_x = points.last.x
        @current_y = points.last.y
      end

      def visit_poly_bezier16(wire)
        points = wire.apts.to_a
        return if points.size < 4

        d = "M #{points.first.x} #{maybe_flip_y(points.first.y)} "
        points[1..].each_slice(3) do |ctrl1, ctrl2, endpt|
          next if [ctrl1, ctrl2, endpt].any?(&:nil?)

          d << "C #{ctrl1.x} #{maybe_flip_y(ctrl1.y)} "
          d << "#{ctrl2.x} #{maybe_flip_y(ctrl2.y)} "
          d << "#{endpt.x} #{maybe_flip_y(endpt.y)} "
        end
        attrs = stroke_attrs.merge("fill" => "none", "d" => d)
        @builder.tag("path", attrs, single: true)
        @current_x = points.last.x
        @current_y = points.last.y
      end

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

      def visit_set_pixel_v(wire)
        # SetPixelV draws a single pixel of a given color at ptlPixel.
        # SVG approximation: a 1x1 rect at the pixel position.
        color = Emf::Model::Geometry::Color.from_wire(wire.cr_color)
        attrs = {
          "x" => wire.ptl_pixel.x, "y" => maybe_flip_y(wire.ptl_pixel.y),
          "width" => 1, "height" => 1, "fill" => color.to_hex
        }
        @builder.tag("rect", attrs, single: true)
      end

      def visit_create_font_indirect_w(wire)
        # Parse the LOGFONT_PANOSE from body bytes. We only extract the
        # face name (UTF-16LE at offset 28 + 28 = 56 bytes into the body,
        # after the fixed LOGFONT fields). Store in object table.
        body = wire.body.to_s
        face_name = parse_logfont_face_name(body, utf16: true)
        font = Font.new(face_name: face_name)
        @object_table.store(wire.ih_object, :font, font)
      end

      def visit_ext_text_out_w(wire)
        emit_ext_text(wire, utf16: true)
      end

      def visit_ext_text_out_a(wire)
        emit_ext_text(wire, utf16: false)
      end

      def visit_intersect_clip_rect(wire)
        # IntersectClipRect restricts the clip region. SVG approximation:
        # wrap subsequent primitives in a <clipPath>. For now, log only.
        # Full clip handling requires maintaining the clip region across
        # records, which is a TODO.
      end

      def visit_exclude_clip_rect(_wire); end

      # --- State-only handlers (no SVG output) ---

      def visit_set_brush_org_ex(wire)
        @dc.brush_origin = [wire.ptl_origin.x, wire.ptl_origin.y]
      end

      def visit_set_metargn(_wire); end

      def visit_offset_clip_rgn(_wire); end

      def visit_set_icm_mode(wire)
        @dc.icm_mode = wire.mode
      end

      def visit_set_layout(wire)
        @dc.layout = wire.mode
      end

      def visit_scale_viewport_ext_ex(_wire); end

      def visit_scale_window_ext_ex(_wire); end

      def visit_set_mapper_flags(wire)
        @dc.mapper_flags = wire.flags
      end

      def visit_set_arc_direction(wire)
        @dc.arc_direction = wire.arc_direction
      end

      def visit_realize_palette(_wire); end

      def visit_select_palette(_wire); end

      def visit_create_palette(_wire); end

      def visit_resize_palette(_wire); end

      def visit_set_palette_entries(_wire); end

      # --- Drawing handlers ---

      def visit_poly_polygon(wire)
        emit_poly_multi(wire.a_poly_counts.to_a, wire.aptl.to_a, closed: true, point_size: 8)
      end

      def visit_poly_polygon16(wire)
        emit_poly_multi(wire.a_poly_counts.to_a, wire.apts.to_a, closed: true, point_size: 4)
      end

      def visit_poly_polyline(wire)
        emit_poly_multi(wire.a_poly_counts.to_a, wire.aptl.to_a, closed: false, point_size: 8)
      end

      def visit_poly_polyline16(wire)
        emit_poly_multi(wire.a_poly_counts.to_a, wire.apts.to_a, closed: false, point_size: 4)
      end

      def visit_poly_draw(wire)
        emit_poly_draw(wire.aptl.to_a, wire.ab_types.to_a, point_size: 8)
      end

      def visit_poly_draw16(wire)
        emit_poly_draw(wire.apts.to_a, wire.ab_types.to_a, point_size: 4)
      end

      def visit_angle_arc(wire)
        # AngleArc: arc on a circle of given radius around ptlCenter,
        # from start_angle to start_angle + sweep_angle (both in degrees).
        cx = wire.ptl_center.x
        cy = wire.ptl_center.y
        r = wire.n_radius
        start_rad = wire.start_angle * Math::PI / 180.0
        sweep_rad = wire.sweep_angle * Math::PI / 180.0
        end_rad = start_rad + sweep_rad
        sx = cx + (r * Math.cos(start_rad))
        sy = cy + (r * Math.sin(start_rad))
        ex = cx + (r * Math.cos(end_rad))
        ey = cy + (r * Math.sin(end_rad))
        large = wire.sweep_angle.abs > 180 ? 1 : 0
        sweep = wire.sweep_angle.negative? ? 0 : 1
        d = format("M %f %f A %f %f 0 %d %d %f %f",
                   sx, maybe_flip_y(sy), r, r, large, sweep, ex, maybe_flip_y(ey))
        attrs = stroke_attrs.merge("fill" => "none", "d" => d)
        @builder.tag("path", attrs, single: true)
      end

      # --- Escape and color-management no-ops ---

      def visit_noop(_wire); end
      def visit_draw_escape(_wire); end
      def visit_ext_escape(_wire); end
      def visit_named_escape(_wire); end
      def visit_small_text_out(_wire); end
      def visit_set_linked_ufis(_wire); end
      def visit_force_ufi_mapping(_wire); end
      def visit_color_correct_palette(_wire); end
      def visit_set_icm_profile_a(_wire); end
      def visit_set_icm_profile_w(_wire); end
      def visit_color_match_to_target_w(_wire); end
      def visit_create_colorspace(_wire); end
      def visit_create_colorspace_w(_wire); end
      def visit_set_colorspace(_wire); end
      def visit_delete_colorspace(_wire); end
      def visit_gls_record(_wire); end
      def visit_gls_bounded_record(_wire); end
      def visit_pixel_format(_wire); end
      def visit_poly_text_out_a(_wire); end
      def visit_poly_text_out_w(_wire); end
      def visit_set_text_justification(_wire); end

      def visit_create_mono_brush(wire)
        @object_table.store(wire.ih_object, :brush, Brush.new(style: Brush::SOLID))
      end

      def visit_create_dib_pattern_brush_pt(wire)
        @object_table.store(wire.ih_object, :brush, Brush.new(style: Brush::PATTERN))
      end

      def visit_ext_create_pen(wire)
        # Full ExtCreatePen layout is complex; for now extract ih_pen
        # and create a default Pen. TODO: parse the full struct.
        pen = Pen.new
        @object_table.store(wire.ih_pen, :pen, pen)
      end

      private

      # LOGFONT_PANOSE face name lives at offset 28 within LOGFONT (after
      # 5-byte fixed prefix and the 23-byte full PANOSE bits in the
      # LOGFONT_PANOSE variant) — but CreateFontIndirectW's body starts
      # at the LOGFONT struct itself, where the face name is at offset 28.
      # The face name is 32 UTF-16LE chars (64 bytes) for LOGFONT_W.
      LOGFONT_FACE_NAME_OFFSET = 28
      LOGFONT_FACE_NAME_MAX_BYTES = 64

      def parse_logfont_face_name(body, utf16:)
        return "sans-serif" if body.bytesize < LOGFONT_FACE_NAME_OFFSET + 2

        raw = body.bytes[LOGFONT_FACE_NAME_OFFSET, LOGFONT_FACE_NAME_MAX_BYTES]
        return "sans-serif" unless raw

        if utf16
          # Take until double-null (string terminator).
          terminated = []
          raw.each_slice(2) do |pair|
            break if pair == [0, 0]

            terminated.concat(pair)
          end
          decoded = terminated.pack("C*").force_encoding("UTF-16LE")
                              .encode("UTF-8", undef: :replace, replace: "?")
          decoded.empty? ? "sans-serif" : decoded
        else
          # 8-bit ANSI; assume CP1252.
          raw.take_while { |b| !b.zero? }.pack("C*").force_encoding("CP1252")
             .encode("UTF-8", undef: :replace, replace: "?")
        end
      rescue StandardError
        "sans-serif"
      end

      def emit_ext_text(wire, utf16:)
        # Offsets are from the start of the EMR record. wire.to_binary_s
        # gives us the full record bytes.
        record_bytes = wire.to_binary_s
        off_string = wire.off_string
        n_chars = wire.n_chars
        return if n_chars.zero? || off_string.zero?
        return if off_string >= record_bytes.bytesize

        string_bytes = record_bytes[off_string, utf16 ? n_chars * 2 : n_chars]
        return unless string_bytes && !string_bytes.empty?

        text = if utf16
                 string_bytes.force_encoding("UTF-16LE")
                             .encode("UTF-8", undef: :replace, replace: "?")
               else
                 string_bytes.force_encoding("CP1252")
                             .encode("UTF-8", undef: :replace, replace: "?")
               end

        # The starting position for ExtTextOut is the WmfRect16 reference
        # point — but in practice the position often comes from a previous
        # MoveToEx. We use the WmfRect16 origin as a fallback.
        x = wire.wmf_rect_left
        y = maybe_flip_y(wire.wmf_rect_top)

        font = @dc.font
        attrs = {
          "x" => x, "y" => y,
          "font-family" => font.face_name,
          "font-size" => font.height,
          "fill" => @dc.text_color.to_hex
        }
        attrs["font-weight"] = "bold" if font.bold?
        attrs["font-style"] = "italic" if font.italic
        attrs["text-decoration"] = "underline" if font.underline
        attrs["text-decoration"] = font.strikeout ? "line-through" : "underline" if font.underline && font.strikeout

        @builder.tag("text", attrs) { @builder.text(text) }
      end

      def emit_arc(wire, mode:)
        l = wire.rcl_box.left
        t = wire.rcl_box.top
        r = wire.rcl_box.right
        b = wire.rcl_box.bottom
        cx = (l + r) / 2.0
        cy = (t + b) / 2.0
        rx = (r - l) / 2.0
        ry = (b - t) / 2.0
        return if rx <= 0 || ry <= 0

        # Start/end angles from rays through ptl_start/ptl_end
        start_ang = Math.atan2(wire.ptl_start.y - cy, wire.ptl_start.x - cx)
        end_ang = Math.atan2(wire.ptl_end.y - cy, wire.ptl_end.x - cx)
        ccw = (@dc.arc_direction || 1) == 2 # AD_COUNTERCLOCKWISE=1, AD_CLOCKWISE=2
        sweep = ccw ? (start_ang - end_ang) : (end_ang - start_ang)
        sweep += (2 * Math::PI) if sweep.negative?
        sweep = (2 * Math::PI) - sweep if sweep > 2 * Math::PI
        large = sweep > Math::PI ? 1 : 0
        sweep_flag = ccw ? 0 : 1
        sx = cx + (rx * Math.cos(start_ang))
        sy = cy + (ry * Math.sin(start_ang))
        ex = cx + (rx * Math.cos(end_ang))
        ey = cy + (ry * Math.sin(end_ang))

        d = "M #{sx} #{maybe_flip_y(sy)} "
        d << format("A %f %f 0 %d %d %f %f", rx, ry, large, sweep_flag, ex, maybe_flip_y(ey))
        case mode
        when :chord
          d << " Z"
        when :pie
          d << format(" L %f %f Z", cx, maybe_flip_y(cy))
        end
        attrs = (mode == :arc ? stroke_attrs : fill_attrs.merge(stroke_attrs)).merge("d" => d)
        @builder.tag("path", attrs, single: true)
      end

      def emit_poly_multi(counts, all_points, closed:, _point_size:)
        return if counts.empty? || all_points.empty?

        # Walk sub-paths, slicing all_points by cumulative counts.
        offset = 0
        counts.each do |count|
          sub_points = all_points[offset, count]
          offset += count
          next unless sub_points && sub_points.size == count

          emit_path_polygon(sub_points, closed: closed)
        end
      end

      def emit_poly_draw(points, types, _point_size:)
        return if points.empty? || types.empty?

        pt_moveto = 1
        pt_lineto = 2
        pt_bezierto = 4
        pt_closefigure = 8

        d = +""
        bezier_buf = []
        i = 0
        types.each_with_index do |t, _idx|
          pt = points[i]
          i += 1
          case t & 0x07
          when pt_moveto
            d << "M #{pt.x} #{maybe_flip_y(pt.y)} "
          when pt_lineto
            d << "L #{pt.x} #{maybe_flip_y(pt.y)} "
          when pt_bezierto
            bezier_buf << pt
            if bezier_buf.size == 3
              d << "C #{bezier_buf[0].x} #{maybe_flip_y(bezier_buf[0].y)} "
              d << "#{bezier_buf[1].x} #{maybe_flip_y(bezier_buf[1].y)} "
              d << "#{bezier_buf[2].x} #{maybe_flip_y(bezier_buf[2].y)} "
              bezier_buf.clear
            end
          end
          d << "Z " if (t & pt_closefigure).nonzero?
        end
        attrs = fill_attrs.merge(stroke_attrs).merge("d" => d)
        @builder.tag("path", attrs, single: true)
      end

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
