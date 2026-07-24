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
        Emf::Emr::Binary::Records::SetMetArgn => :visit_set_metargn,
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
        Emf::Emr::Binary::Records::ExtCreatePen => :visit_ext_create_pen,
        Emf::Emr::Binary::Records::StretchDIBits => :visit_stretch_dibits,
        Emf::Emr::Binary::Records::AlphaBlend => :visit_alpha_blend,
        Emf::Emr::Binary::Records::TransparentBlt => :visit_transparent_blt,
        Emf::Emr::Binary::Records::BitBlt => :visit_bit_blt,
        Emf::Emr::Binary::Records::StretchBlt => :visit_stretch_blt,
        Emf::Emr::Binary::Records::ExtSelectClipRgn => :visit_ext_select_clip_rgn,
        Emf::Emr::Binary::Records::GradientFill => :visit_gradient_fill,
        Emf::Emr::Binary::Records::FillRgn => :visit_fill_rgn,
        Emf::Emr::Binary::Records::FrameRgn => :visit_frame_rgn,
        Emf::Emr::Binary::Records::InvertRgn => :visit_invert_rgn,
        Emf::Emr::Binary::Records::PaintRgn => :visit_paint_rgn
      }.freeze

      def initialize(builder, dc, object_table, transform_stack, bounds, fix_y, options,
                     scaling: 1.0, ref_x: 0.0, ref_y: 0.0, px_per_mm: 1.0)
        @builder = builder
        @dc = dc
        @object_table = object_table
        @transform_stack = transform_stack
        @bounds = bounds
        @fix_y = fix_y
        @options = options
        @scaling = scaling
        @ref_x = ref_x
        @ref_y = ref_y
        @px_per_mm = px_per_mm
        @current_x = 0
        @current_y = 0
        @path_d = nil
        @open_groups = 0
      end

      attr_reader :current_x, :current_y, :open_groups

      def open_group_count
        @open_groups
      end

      # The Emf wire-record-adapter calls this. Dispatch by wire class.
      def visit_emr_wire_record(adapter)
        wire = adapter.wire
        method_name = HANDLERS[wire.class]
        if method_name
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

      # Per-element coordinate transformation matching libemf2svg's point_cal().
      #
      # CRITICAL: window/viewport origins are ONLY applied for ISOTROPIC and
      # ANISOTROPIC modes. For MM_TEXT and metric modes, the C code leaves
      # windowOrgX/Y and viewPortOrgX/Y at 0.0 (initialized but never set
      # inside the switch). This is NOT a bug in the C code — it's the
      # intentional GDI behavior for those map modes.

      def cal_x(x)
        if use_orgs?
          (((x - @dc.window_org[0]) * sf_x) + @dc.viewport_org[0]) * @scaling
        else
          x * sf_x * @scaling
        end
      end

      def cal_y(y)
        if use_orgs?
          (((y - @dc.window_org[1]) * sf_y) + @dc.viewport_org[1]) * @scaling
        else
          y * sf_y * @scaling
        end
      end

      def use_orgs?
        @dc.map_mode == 7 || @dc.map_mode == 8 # ISOTROPIC or ANISOTROPIC
      end

      def scale_dim_x(w)
        w * sf_x * @scaling
      end

      def scale_dim_y(h)
        h * sf_y.abs * @scaling
      end

      def fmt(n)
        format("%.4f", n.to_f)
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

      ColorRGB = Struct.new(:r, :g, :b) do
        def to_color
          Emf::Model::Geometry::Color.new(red: r, green: g, blue: b)
        end
      end

      STOCK_OBJECT_FLAG = 0x80000000
      # Stock object indices (low 31 bits when STOCK_OBJECT_FLAG is set),
      # matching MS-EMF 2.1.7. Used by visit_select_object.
      STOCK = {
        0 => [:brush, :white],   # WHITE_BRUSH
        1 => [:brush, :ltgray],  # LTGRAY_BRUSH
        2 => [:brush, :gray],    # GRAY_BRUSH
        3 => [:brush, :dkgray],  # DKGRAY_BRUSH
        4 => [:brush, :black],   # BLACK_BRUSH
        5 => [:brush, :null],    # NULL_BRUSH
        6 => [:pen, :white],     # WHITE_PEN
        7 => [:pen, :black],     # BLACK_PEN
        8 => [:pen, :null]       # NULL_PEN
      }.freeze

      STOCK_BRUSH_COLORS = {
        white: ColorRGB.new(0xFF, 0xFF, 0xFF),
        ltgray: ColorRGB.new(0xC0, 0xC0, 0xC0),
        gray: ColorRGB.new(0x80, 0x80, 0x80),
        dkgray: ColorRGB.new(0x40, 0x40, 0x40),
        black: ColorRGB.new(0x00, 0x00, 0x00)
      }.freeze

      def visit_select_object(wire)
        ih = wire.ih_object

        # Stock object?
        if (ih & STOCK_OBJECT_FLAG).positive?
          index = ih & 0x7FFFFFFF
          apply_stock_object(index)
          return
        end

        entry = @object_table.lookup(ih)
        return unless entry

        case entry.type
        when :pen then @dc.pen = entry.object
        when :brush then @dc.brush = entry.object
        when :font then @dc.font = entry.object
        end
      end

      def apply_stock_object(index)
        kind, variant = STOCK[index]
        return unless kind

        case kind
        when :brush
          if variant == :null
            @dc.brush = Brush.new(style: Brush::NULL,
                                  color: Emf::Model::Geometry::Color.white)
          else
            @dc.brush = Brush.new(style: Brush::SOLID,
                                  color: STOCK_BRUSH_COLORS[variant].to_color)
          end
        when :pen
          if variant == :null
            @dc.pen = Pen.new(style: Pen::NULL, width: 1,
                              color: Emf::Model::Geometry::Color.black)
          else
            @dc.pen = Pen.new(style: Pen::SOLID, width: 1,
                              color: STOCK_BRUSH_COLORS[variant].to_color)
          end
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

      def visit_set_window_org_ex(wire)
        @dc.window_org = [wire.origin.x, wire.origin.y]
      end

      def visit_set_window_ext_ex(wire)
        @dc.window_ext = [wire.extent.cx, wire.extent.cy]
      end

      def visit_set_viewport_org_ex(wire)
        @dc.viewport_org = [wire.origin.x, wire.origin.y]
      end

      def visit_set_viewport_ext_ex(wire)
        @dc.viewport_ext = [wire.extent.cx, wire.extent.cy]
      end

      def visit_move_to_ex(wire)
        @current_x = wire.origin.x
        @current_y = wire.origin.y
      end

      def visit_line_to(wire)
        # Matches U_EMRLINETO_draw → lineto_draw → startPathDraw + "L X,Y " + endPathDraw
        # endPathDraw emits ` fill="none"` (WITH leading space) — different
        # from U_EMRPOLYLINE_draw which emits `fill="none"` (no leading).
        d = +"M #{fmt(cal_x(@current_x))},#{fmt(cal_y(@current_y))} "
        d << "L #{fmt(cal_x(wire.origin.x))},#{fmt(cal_y(wire.origin.y))} "
        emit_path_element(d, closed: false, leading_fill_space: true)
        @current_x = wire.origin.x
        @current_y = wire.origin.y
      end

      def visit_rectangle(wire)
        lt_x = cal_x(wire.rcl_box.left)
        lt_y = cal_y(wire.rcl_box.top)
        rb_x = cal_x(wire.rcl_box.right)
        rb_y = cal_y(wire.rcl_box.bottom)
        dim_x = rb_x - lt_x
        dim_y = rb_y - lt_y
        if @fix_y && dim_y.negative?
          dim_y = -dim_y
          lt_y -= dim_y
        end
        geom = format("x=\"%.4f\" y=\"%.4f\" width=\"%.4f\" height=\"%.4f\"",
                      lt_x, lt_y, dim_x, dim_y)
        emit_shape_element("rect", geom)
      end

      def visit_ellipse(wire)
        lt_x = cal_x(wire.rcl_box.left)
        lt_y = cal_y(wire.rcl_box.top)
        rb_x = cal_x(wire.rcl_box.right)
        rb_y = cal_y(wire.rcl_box.bottom)
        cx = (lt_x + rb_x) / 2.0
        cy = (lt_y + rb_y) / 2.0
        rx = (rb_x - lt_x).abs / 2.0
        ry = (rb_y - lt_y).abs / 2.0
        geom = format("cx=\"%.4f\" cy=\"%.4f\" rx=\"%.4f\" ry=\"%.4f\"",
                      cx, cy, rx, ry)
        emit_shape_element("ellipse", geom)
      end

      def visit_round_rect(wire)
        lt_x = cal_x(wire.rcl_box.left)
        lt_y = cal_y(wire.rcl_box.top)
        rb_x = cal_x(wire.rcl_box.right)
        rb_y = cal_y(wire.rcl_box.bottom)
        dim_x = rb_x - lt_x
        dim_y = rb_y - lt_y
        if @fix_y && dim_y.negative?
          dim_y = -dim_y
          lt_y -= dim_y
        end
        rx = scale_dim_x(wire.szl_corner.cx.to_i)
        ry = scale_dim_x(wire.szl_corner.cy.to_i)
        geom = format("x=\"%.4f\" y=\"%.4f\" width=\"%.4f\" height=\"%.4f\" rx=\"%.4f\" ry=\"%.4f\"",
                      lt_x, lt_y, dim_x, dim_y, rx, ry)
        emit_shape_element("rect", geom)
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

      def visit_poly_bezier(wire)
        emit_poly_bezier_common(wire.aptl.to_a, starting_point: true)
      end

      def visit_poly_bezier16(wire)
        emit_poly_bezier_common(wire.apts.to_a, starting_point: true)
      end

      # Matches cubic_bezier_draw / cubic_bezier16_draw.
      # startPathDraw emits `M cur_x,cur_y ` (from the device context's
      # current position). If starting_point is true (PolyBezier, not To),
      # an additional `M point[0]` is emitted before the C commands.
      def emit_poly_bezier_common(points, starting_point:)
        return if points.size < 4

        d = +"M #{fmt(cal_x(@current_x))},#{fmt(cal_y(@current_y))} "
        if starting_point
          d << "M "
          d << point_str(points.first)
        end
        points[1..].each_slice(3) do |ctrl1, ctrl2, endpt|
          next if [ctrl1, ctrl2, endpt].any?(&:nil?)

          d << "C "
          d << point_str(ctrl1)
          d << point_str(ctrl2)
          d << point_str(endpt)
        end
        emit_path_element(d, closed: false, leading_fill_space: true)
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

      def visit_set_pixel_v(_wire)
        # FLAG_IGNORED in libemf2svg — emits nothing.
      end

      def visit_create_font_indirect_w(wire)
        body = wire.body.to_s
        font = parse_logfont(body, utf16: true)
        @object_table.store(wire.ih_object, :font, font)
      end

      # Parse a LOGFONT struct from body bytes (MS-WMF 2.2.13).
      # Layout:
      #   0  int32 lfHeight
      #   4  int32 lfWidth
      #   8  int32 lfEscapement (tenths of a degree)
      #   12 int32 lfOrientation
      #   16 int32 lfWeight
      #   20 byte  lfItalic
      #   21 byte  lfUnderline
      #   22 byte  lfStrikeOut
      #   ... (charset etc ignored)
      #   28 32 UTF-16 chars lfFaceName (64 bytes)
      def parse_logfont(body, utf16:)
        return Font.default if body.nil? || body.bytesize < 28

        height = body.unpack("l<")[0]
        _width = body.unpack("l<", offset: 4)[0]
        # libemf2svg reduces lfEscapement modulo 3600 (so 3600 → 0, no rotation).
        escapement = body.unpack("l<", offset: 8)[0] % 3600
        weight = body.unpack("l<", offset: 16)[0]
        italic = body.getbyte(20) != 0
        underline = body.getbyte(21) != 0
        strikeout = body.getbyte(22) != 0
        face_name = parse_logfont_face_name(body, utf16: utf16)
        Font.new(face_name: face_name, height: height, weight: weight,
                 italic: italic, underline: underline, strikeout: strikeout,
                 escapement: escapement)
      rescue StandardError
        Font.default
      end

      def visit_ext_text_out_w(wire)
        emit_ext_text(wire, utf16: true)
      end

      def visit_ext_text_out_a(wire)
        emit_ext_text(wire, utf16: false)
      end

      def visit_intersect_clip_rect(wire)
        # libemf2svg's clip_rgn_mix ignores the mode and REPLACES the clip
        # region with the new rect. We replicate that.
        @dc.clip_region = ClipRegion.new(bounds: Emf::Model::Geometry::Rect.from_wire(wire.rcl_clip))
        emit_clip_def(@dc.clip_region)
      end

      def visit_exclude_clip_rect(wire)
        @dc.clip_region = ClipRegion.new(bounds: Emf::Model::Geometry::Rect.from_wire(wire.rcl_clip))
        emit_clip_def(@dc.clip_region)
      end

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
        emit_poly_multi(wire.a_poly_counts.to_a, wire.aptl.to_a, closed: true, _point_size: 8)
      end

      def visit_poly_polygon16(wire)
        emit_poly_multi(wire.a_poly_counts.to_a, wire.apts.to_a, closed: true, _point_size: 4)
      end

      def visit_poly_polyline(wire)
        emit_poly_multi(wire.a_poly_counts.to_a, wire.aptl.to_a, closed: false, _point_size: 8)
      end

      def visit_poly_polyline16(wire)
        emit_poly_multi(wire.a_poly_counts.to_a, wire.apts.to_a, closed: false, _point_size: 4)
      end

      def visit_poly_draw(wire)
        emit_poly_draw(wire.aptl.to_a, wire.ab_types.to_a, _point_size: 8)
      end

      def visit_poly_draw16(wire)
        emit_poly_draw(wire.apts.to_a, wire.ab_types.to_a, _point_size: 4)
      end

      def visit_angle_arc(wire)
        # Mirror libemf2svg's arc_circle_draw:
        #   startPathDraw emits `<path d="M cur_x,cur_y `
        #   then `M start_x,start_y A radii 0 large_arc sweep end_x,end_y `
        #   then endPathDraw emits closing quote + stroke + ` fill="none" />`
        cx_raw = wire.ptl_center.x
        cy_raw = wire.ptl_center.y
        r_raw = wire.n_radius
        start_angle = wire.start_angle
        sweep_angle = wire.sweep_angle

        # arcdir: 1 = AD_COUNTERCLOCKWISE (sweep=large=0), else 1/1.
        arcdir = @dc.arc_direction || 1
        sweep_flag = arcdir.positive? ? 1 : 0
        large_arc_flag = arcdir.positive? ? 1 : 0

        start_rad = start_angle * Math::PI / 180.0
        end_rad = (start_angle + sweep_angle) * Math::PI / 180.0
        sx_raw = (r_raw * Math.cos(start_rad)) + cx_raw
        sy_raw = (r_raw * Math.sin(start_rad)) + cy_raw
        ex_raw = (r_raw * Math.cos(end_rad)) + cx_raw
        ey_raw = (r_raw * Math.sin(end_rad)) + cy_raw

        d = +"M "
        d << format("%.4f,%.4f ", cal_x(@current_x), cal_y(@current_y))
        d << "M "
        d << format("%.4f,%.4f ", cal_x(sx_raw), cal_y(sy_raw))
        d << "A "
        d << format("%.4f,%.4f ", scale_dim_x(r_raw), scale_dim_y(r_raw))
        d << "0 "
        d << "#{large_arc_flag} #{sweep_flag} "
        d << format("%.4f,%.4f ", cal_x(ex_raw), cal_y(ey_raw))
        emit_path_element(d, closed: false, leading_fill_space: true)
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

      # --- Region operations (TODO 08) ---

      def visit_fill_rgn(wire)
        bounds = parse_rgn_body_bounds(wire.body.to_s)
        return unless bounds

        entry = @object_table.lookup(wire.ih_brush)
        color = entry&.brush? ? entry.object.color : @dc.brush.color
        attrs = {
          "x" => bounds.left, "y" => maybe_flip_y(bounds.top),
          "width" => bounds.right - bounds.left,
          "height" => bounds.bottom - bounds.top,
          "fill" => color.to_hex
        }.merge(clip_attrs)
        @builder.tag("rect", attrs, single: true)
      end

      def visit_frame_rgn(wire)
        bounds = parse_rgn_body_bounds(wire.body.to_s)
        return unless bounds

        entry = @object_table.lookup(wire.ih_brush)
        color = entry&.brush? ? entry.object.color : @dc.brush.color
        attrs = {
          "x" => bounds.left, "y" => maybe_flip_y(bounds.top),
          "width" => bounds.right - bounds.left,
          "height" => bounds.bottom - bounds.top,
          "fill" => "none", "stroke" => color.to_hex, "stroke-width" => 1
        }.merge(clip_attrs)
        @builder.tag("rect", attrs, single: true)
      end

      def visit_invert_rgn(wire)
        bounds = parse_rgn_body_bounds(wire.body.to_s)
        return unless bounds

        attrs = {
          "x" => bounds.left, "y" => maybe_flip_y(bounds.top),
          "width" => bounds.right - bounds.left,
          "height" => bounds.bottom - bounds.top,
          "fill" => "#FFFFFF", "filter" => "url(#invert)"
        }.merge(clip_attrs)
        @builder.tag("rect", attrs, single: true)
      end

      def visit_paint_rgn(wire)
        bounds = parse_rgn_body_bounds(wire.body.to_s)
        return unless bounds

        attrs = {
          "x" => bounds.left, "y" => maybe_flip_y(bounds.top),
          "width" => bounds.right - bounds.left,
          "height" => bounds.bottom - bounds.top
        }.merge(fill_attrs).merge(clip_attrs)
        @builder.tag("rect", attrs, single: true)
      end

      def visit_ext_create_pen(wire)
        # EMREXTCREATEPEN body layout (after EMR + ihPen) per MS-EMF 2.3.7.9:
        #   offBmi (4), cbBmi (4), offBits (4), cbBits (4),
        #   then EXTLOGPEN32:
        #     elpPenStyle (4), elpWidth (4), elpBrushStyle (4),
        #     elpColor (COLORREF: B,G,R,reserved — 4 bytes),
        #     elpHatch (4), elpNumEntries (4), elpStyleEntry[]
        body = wire.body.to_s
        if body.bytesize >= 32
          pen_style = body.unpack1("V", offset: 16)
          width = body.unpack1("V", offset: 20)
          # COLORREF at body offset 28: B,G,R,reserved
          b = body.getbyte(28)
          g = body.getbyte(29)
          r = body.getbyte(30)
          pen = Pen.new(
            style: pen_style,
            width: width,
            color: Emf::Model::Geometry::Color.new(red: r, green: g, blue: b)
          )
          @object_table.store(wire.ih_pen, :pen, pen)
        else
          @object_table.store(wire.ih_pen, :pen, Pen.new)
        end
      end

      # --- Bitmap handlers ---

      def visit_stretch_dibits(wire)
        record_bytes = wire.to_binary_s
        emit_image_from_dib(
          record_bytes, wire.off_bmi_src, wire.cb_bmi_src,
          wire.off_bits_src, wire.cb_bits_src,
          x: wire.x_dest, y: wire.y_dest,
          width: wire.cx_dest, height: wire.cy_dest
        )
      end

      def visit_alpha_blend(wire)
        # AlphaBlend has a similar layout to StretchDIBits but with
        # a fixed alpha (bfBlendOp) and explicit source/dest dimensions.
        # The trailing body contains the BITMAPINFO + pixels.
        # For MVP: emit an image element using bounds-derived position.
        emit_image_from_body(
          wire, wire.rcl_bounds.left, wire.rcl_bounds.top,
          wire.rcl_bounds.right - wire.rcl_bounds.left,
          wire.rcl_bounds.bottom - wire.rcl_bounds.top
        )
      end

      def visit_transparent_blt(wire)
        emit_image_from_body(
          wire, wire.rcl_bounds.left, wire.rcl_bounds.top,
          wire.rcl_bounds.right - wire.rcl_bounds.left,
          wire.rcl_bounds.bottom - wire.rcl_bounds.top
        )
      end

      def visit_bit_blt(wire)
        emit_image_from_body(
          wire, wire.rcl_bounds.left, wire.rcl_bounds.top,
          wire.rcl_bounds.right - wire.rcl_bounds.left,
          wire.rcl_bounds.bottom - wire.rcl_bounds.top
        )
      end

      def visit_stretch_blt(wire)
        emit_image_from_body(
          wire, wire.rcl_bounds.left, wire.rcl_bounds.top,
          wire.rcl_bounds.right - wire.rcl_bounds.left,
          wire.rcl_bounds.bottom - wire.rcl_bounds.top
        )
      end

      # --- Clip region handlers (TODO 06) ---

      def visit_ext_select_clip_rgn(wire)
        # RGN_COPY (5) with no region data resets the clip in libemf2svg.
        if wire.dw_mode == 5 || wire.dw_mode.zero?
          @dc.clip_region = nil
          @dc.clip_id = nil
          return
        end

        bounds = parse_rgn_data_bounds(wire.rgn_data.to_s)
        new_region = bounds ? ClipRegion.new(bounds: bounds) : ClipRegion.new
        @dc.clip_region = new_region
        emit_clip_def(@dc.clip_region)
      end

      def visit_select_clip_path(_wire)
        return unless @path_d && !@path_d.empty?

        @dc.clip_region = ClipRegion.new(path_d: @path_d.dup)
        emit_clip_def(@dc.clip_region)
      end

      def visit_gradient_fill(wire)
        body = wire.body.to_s
        wire.ul_mode
        n_ver = wire.n_ver
        return if n_ver.nil? || n_ver.zero? || body.bytesize < n_ver * 16

        # Parse Trivertex structs: x, y, red, green, blue, alpha (4+4+2+2+2+2 = 16)
        vertices = (0...n_ver).map do |i|
          off = i * 16
          {
            x: body.getbyte(off) | (body.getbyte(off + 1) << 8) | (body.getbyte(off + 2) << 16) | (body.getbyte(off + 3) << 24),
            y: body.getbyte(off + 4) | (body.getbyte(off + 5) << 8) | (body.getbyte(off + 6) << 16) | (body.getbyte(off + 7) << 24),
            red: body.getbyte(off + 8) | (body.getbyte(off + 9) << 8),
            green: body.getbyte(off + 10) | (body.getbyte(off + 11) << 8),
            blue: body.getbyte(off + 12) | (body.getbyte(off + 13) << 8),
            alpha: body.getbyte(off + 14) | (body.getbyte(off + 15) << 8)
          }
        end
        # For MVP we emit a single rect with an average colour per vertex pair.
        # Full gradient rendering is a follow-up.
        vertices.each_slice(2) do |v0, v1|
          next unless v1

          x0 = v0[:x]
          y0 = v0[:y]
          x1 = v1[:x]
          y1 = v1[:y]
          attrs = {
            "x" => x0, "y" => maybe_flip_y(y0),
            "width" => (x1 - x0).abs, "height" => (y1 - y0).abs,
            "fill" => format("#%04X%04X%04X", v0[:red], v0[:green], v0[:blue])[0, 7]
          }
          @builder.tag("rect", attrs, single: true)
        end
      end

      private

      def parse_rgn_data_bounds(rgn_data)
        return nil if rgn_data.nil? || rgn_data.bytesize < 32

        # RGNDATAHEADER.rclBounds at offset 16
        left = rgn_data.getbyte(16) | (rgn_data.getbyte(17) << 8) |
               (rgn_data.getbyte(18) << 16) | (rgn_data.getbyte(19) << 24)
        top = rgn_data.getbyte(20) | (rgn_data.getbyte(21) << 8) |
              (rgn_data.getbyte(22) << 16) | (rgn_data.getbyte(23) << 24)
        right = rgn_data.getbyte(24) | (rgn_data.getbyte(25) << 8) |
                (rgn_data.getbyte(26) << 16) | (rgn_data.getbyte(27) << 24)
        bottom = rgn_data.getbyte(28) | (rgn_data.getbyte(29) << 8) |
                 (rgn_data.getbyte(30) << 16) | (rgn_data.getbyte(31) << 24)
        Emf::Model::Geometry::Rect.new(left: left, top: top, right: right, bottom: bottom)
      end

      # Region ops (FillRgn etc.) carry ih_brush then cbRgnData then
      # RGNDATA. Extract bounds from the body.
      def parse_rgn_body_bounds(body)
        return nil if body.nil? || body.bytesize < 36

        # body layout: cbRgnData (4) + RGNDATAHEADER (32 min)
        # rclBounds is at RGNDATAHEADER offset 16 = body offset 4+16 = 20
        left = body.getbyte(20) | (body.getbyte(21) << 8) |
               (body.getbyte(22) << 16) | (body.getbyte(23) << 24)
        top = body.getbyte(24) | (body.getbyte(25) << 8) |
              (body.getbyte(26) << 16) | (body.getbyte(27) << 24)
        right = body.getbyte(28) | (body.getbyte(29) << 8) |
                (body.getbyte(30) << 16) | (body.getbyte(31) << 24)
        bottom = body.getbyte(32) | (body.getbyte(33) << 8) |
                 (body.getbyte(34) << 16) | (body.getbyte(35) << 24)
        Emf::Model::Geometry::Rect.new(left: left, top: top, right: right, bottom: bottom)
      end

      def emit_clip_def(region)
        return if region.nil? || region.empty?

        clip_id = BsdRand.next
        @builder.raw("<defs><clipPath id=\"clip-#{clip_id}\">")
        @builder.raw("<path d=\"")
        @builder.raw(clip_region_path_d(region))
        @builder.raw("Z\" />")
        @builder.rawln("</clipPath></defs>")
        @dc.clip_id = clip_id
      end

      # Build the path-d string for a clip region matching libemf2svg's
      # draw_path output (segments: M, L, ..., then implicit Z appended by
      # caller).
      def clip_region_path_d(region)
        if region.path_d
          region.path_d
        elsif region.bounds
          b = region.bounds
          pts = [[b.left, b.top], [b.right, b.top],
                 [b.right, b.bottom], [b.left, b.bottom], [b.left, b.top]]
          d = +"M "
          d << format("%.4f,%.4f ", cal_x(pts.first[0]), cal_y(pts.first[1]))
          pts[1..].each do |x, y|
            d << "L "
            d << format("%.4f,%.4f ", cal_x(x), cal_y(y))
          end
          d << "Z "
          d
        else
          ""
        end
      end

      def clip_attrs
        return {} unless @dc.clip_id

        { "clip-path" => "url(#clip-#{@dc.clip_id})" }
      end

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
        record_bytes = wire.to_binary_s
        off_string = wire.off_string
        n_chars = wire.n_chars

        text = if off_string && off_string.positive? && off_string < record_bytes.bytesize
                 string_bytes = record_bytes[off_string, utf16 ? n_chars * 2 : n_chars]
                 if string_bytes && !string_bytes.empty?
                   if utf16
                     string_bytes.force_encoding("UTF-16LE")
                                 .encode("UTF-8", undef: :replace, replace: "?")
                   else
                     string_bytes.force_encoding("CP1252")
                                 .encode("UTF-8", undef: :replace, replace: "?")
                   end
                 else
                   ""
                 end
               else
                 ""
               end

        # libemf2svg emits the <text> element even when the string is empty.
        x = cal_x(wire.ptl_reference.x)
        y = cal_y(wire.ptl_reference.y)

        font = @dc.font
        font_height = (scale_dim_x(font.height.to_i)).abs

        @builder.raw("<text ")
        @builder.raw(clip_path_attr_string)
        emit_text_style(font, font_height, x, y)
        @builder.raw(">")
        @builder.raw("<![CDATA[#{text}]]>")
        @builder.rawln("</text>")
      end

      # Mirror libemf2svg's text_style_draw. Attributes are written in the
      # exact C order with the exact spacing, including the quirky
      # `style ="..."` (space before `=`).
      # NOTE: text_style_draw does NOT prefix with a space; the caller
      # (text_draw) emits the trailing space of `<text ` (and any trailing
      # space from clipset_draw) before this method runs.
      def emit_text_style(font, font_height, x, y)
        @builder.raw("font-family=\"#{font.face_name}\" ") if font.face_name
        @builder.raw("fill=\"#{@dc.text_color.to_hex}\" ")

        orientation = sf_y > 0 ? -1 : 1
        if font.escapement != 0
          rotation = orientation * font.escapement / 10
          @builder.raw(format("transform=\"rotate(%d, %.4f, %.4f) translate(0, %.4f)\" ",
                              rotation, x, (y + font_height * 0.9), font_height * 0.9))
        end

        @builder.raw("font-style=\"italic\" ") if font.italic
        # Quirk: libemf2svg prints "style =\"...\"" with a space before `=`.
        @builder.raw("style =\"white-space:pre;\" ")

        if font.underline && font.strikeout
          @builder.raw("text-decoration=\"line-through,underline\" ")
        elsif font.underline
          @builder.raw("text-decoration=\"underline\" ")
        elsif font.strikeout
          @builder.raw("text-decoration=\"line-through\" ")
        end

        @builder.raw("font-weight=\"#{font.weight}\" ") if font.weight != 0

        align = @dc.text_align
        anchor = case align & 0x06
                 when 0x06 then "middle"
                 when 0x02 then "end"
                 else "start"
                 end
        @builder.raw("text-anchor=\"#{anchor}\" ")

        # Vertical position: TA_BOTTOM (0x08) or TA_BASELINE (0x18) use Org.y;
        # otherwise add font_height * 0.9.
        if (align & 0x18) == 0x18 || (align & 0x18) == 0x08
          y_pos = y
        else
          y_pos = y + (font_height * 0.9)
        end
        @builder.raw(format("x=\"%.4f\" y=\"%.4f\" ", x, y_pos))
        @builder.raw(format("font-size=\"%.4f\" ", font_height))
      end

      def emit_arc(wire, mode:)
        l = cal_x(wire.rcl_box.left)
        t = cal_y(wire.rcl_box.top)
        r = cal_x(wire.rcl_box.right)
        b = cal_y(wire.rcl_box.bottom)
        cx = (l + r) / 2.0
        cy = (t + b) / 2.0
        rx = (r - l).abs / 2.0
        ry = (b - t).abs / 2.0
        return if rx <= 0 || ry <= 0

        ps_x = cal_x(wire.ptl_start.x)
        ps_y = cal_y(wire.ptl_start.y)
        pe_x = cal_x(wire.ptl_end.x)
        pe_y = cal_y(wire.ptl_end.y)
        start_ang = Math.atan2(ps_y - cy, ps_x - cx)
        end_ang = Math.atan2(pe_y - cy, pe_x - cx)
        ccw = (@dc.arc_direction || 1) == 2
        sweep = ccw ? (start_ang - end_ang) : (end_ang - start_ang)
        sweep += (2 * Math::PI) if sweep.negative?
        sweep = (2 * Math::PI) - sweep if sweep > 2 * Math::PI
        large = sweep > Math::PI ? 1 : 0
        sweep_flag = ccw ? 0 : 1
        sx = cx + (rx * Math.cos(start_ang))
        sy = cy + (ry * Math.sin(start_ang))
        ex = cx + (rx * Math.cos(end_ang))
        ey = cy + (ry * Math.sin(end_ang))

        d = "M #{fmt(sx)} #{fmt(sy)} "
        d << format("A %.4f %.4f 0 %d %d %.4f %.4f", rx, ry, large, sweep_flag, ex, ey)
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

        # libemf2svg emits ALL sub-polygons in a single <path> element,
        # separated by Z M between sub-polygons. Each sub-polygon ends with
        # `Z `, then the next starts with `M `. The path closes with `Z" `
        # (single Z appended by U_EMRPOLYPOLYGON_draw).
        d = +""
        offset = 0
        counts.each_with_index do |count, _idx|
          sub_points = all_points[offset, count]
          offset += count
          next unless sub_points && sub_points.size == count

          d << "M "
          d << point_str(sub_points.first)
          sub_points[1..].each do |p|
            d << "L "
            d << point_str(p)
          end
          d << "Z " if closed
        end
        return if d.empty?

        # PolyPolygon emits as a closed path (Z already in d-string, then
        # U_EMRPOLYPOLYGON_draw appends another Z and `"`).
        @builder.raw("<path ")
        @builder.raw(clip_path_attr_string)
        @builder.raw("d=\"")
        @builder.raw(d)
        @builder.raw("Z\" ")
        emit_stroke_draw
        emit_fill_draw
        emit_unfilled_unstroked
        @builder.raw("/>")
        @builder.newline
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
            d << "M #{fmt(cal_x(pt.x))} #{fmt(cal_y(pt.y))} "
          when pt_lineto
            d << "L #{fmt(cal_x(pt.x))} #{fmt(cal_y(pt.y))} "
          when pt_bezierto
            bezier_buf << pt
            if bezier_buf.size == 3
              d << "C #{fmt(cal_x(bezier_buf[0].x))} #{fmt(cal_y(bezier_buf[0].y))} "
              d << "#{fmt(cal_x(bezier_buf[1].x))} #{fmt(cal_y(bezier_buf[1].y))} "
              d << "#{fmt(cal_x(bezier_buf[2].x))} #{fmt(cal_y(bezier_buf[2].y))} "
              bezier_buf.clear
            end
          end
          d << "Z " if (t & pt_closefigure).nonzero?
        end
        attrs = fill_attrs.merge(stroke_attrs).merge("d" => d)
        @builder.tag("path", attrs, single: true)
      end

      def emit_image_from_dib(record_bytes, off_bmi, cb_bmi, off_bits, cb_bits, x:, y:, width:, height:)
        return if off_bmi.zero? || cb_bmi.zero?

        bmi_bytes = record_bytes[off_bmi, cb_bmi]
        bits_bytes = record_bytes[off_bits, cb_bits] || +""
        dib_bytes = bmi_bytes.to_s + bits_bytes.to_s
        result = DibDecoder.decode(dib_bytes)
        return unless result

        href = build_image_href(result)
        attrs = {
          "x" => x, "y" => maybe_flip_y(y),
          "width" => width, "height" => height,
          "xlink:href" => href, "preserveAspectRatio" => "none"
        }
        @builder.tag("image", attrs, single: true)
      end

      def emit_image_from_body(wire, x, y, width, height)
        # For wire classes where we haven't decoded the BMI offsets:
        # try to find the bitmap data in the trailing body.
        body = if wire.is_a?(Emf::Emr::Binary::Records::StretchDIBits)
                 wire.trailing.to_s
               else
                 wire.body.to_s
               end
        return if body.bytesize < 40

        result = DibDecoder.decode(body)
        return unless result

        href = build_image_href(result)
        attrs = {
          "x" => x, "y" => maybe_flip_y(y),
          "width" => width, "height" => height,
          "xlink:href" => href, "preserveAspectRatio" => "none"
        }
        @builder.tag("image", attrs, single: true)
      end

      def build_image_href(result)
        case result.color_type
        when :jpeg
          "data:image/jpeg;base64,#{[result.pixels].pack('m0')}"
        when :png
          "data:image/png;base64,#{[result.pixels].pack('m0')}"
        else
          png_bytes = PngEncoder.encode(result.width, result.height, result.pixels)
          "data:image/png;base64,#{[png_bytes].pack('m0')}"
        end
      end

      def emit_path_polygon(points, closed:)
        return if points.empty?

        d = +"M "
        d << point_str(points.first)
        points[1..].each do |p|
          d << "L "
          d << point_str(p)
        end
        emit_path_element(d, closed: closed)
      end

      # Emits a <path> element matching libemf2svg's exact byte layout:
      #   <path [clip-path="..."] d="..."Z" [stroke attrs] [fill attrs] [...]/>\n
      # For closed paths the trailing Z is appended; for open paths it's omitted.
      # Stroke is emitted before fill (matching U_EMRPOLYGON_draw ordering).
      def emit_path_element(d_string, closed:, leading_fill_space: false)
        @builder.raw("<path ")
        @builder.raw(clip_path_attr_string)
        @builder.raw("d=\"")
        @builder.raw(d_string)
        @builder.raw(closed ? "Z\" " : "\" ")
        emit_stroke_draw
        if closed
          emit_fill_draw
          emit_unfilled_unstroked
        else
          # Open paths: no fill_draw call. libemf2svg emits `fill="none"` as
          # fallback. LineTo (endPathDraw) prefixes with a space; Polyline
          # does not.
          @builder.raw(" ") if leading_fill_space
          @builder.raw("fill=\"none\" ")
          @builder.raw("stroke=\"none\" ") unless @last_stroke_set
        end
        @builder.raw("/>")
        @builder.newline
      end

      # Emits a shape element (rect/ellipse) matching libemf2svg byte layout:
      #   <rect x=".." y=".." width=".." height=".." [rx ry] [fill] [stroke] [clip]/>\n
      # Fill is emitted before stroke (matching U_EMRRECTANGLE_draw ordering).
      def emit_shape_element(tag_name, geometry_str)
        @builder.raw("<")
        @builder.raw(tag_name)
        @builder.raw(" ")
        @builder.raw(geometry_str)
        @builder.raw(" ")
        emit_fill_draw
        emit_stroke_draw
        @builder.raw(clip_path_attr_string)
        emit_unfilled_unstroked
        @builder.raw("/>")
        @builder.newline
      end

      # Mirror libemf2svg's "if (!filled) fill=\"none\"" / "if (!stroked) stroke=\"none\""
      # trailing fallbacks. Tracks state via @last_fill_set / @last_stroke_set.
      def emit_unfilled_unstroked
        @builder.raw("fill=\"none\" ") unless @last_fill_set
        @builder.raw("stroke=\"none\" ") unless @last_stroke_set
      end

      # Format a single point as libemf2svg's point_draw would: "X,Y "
      def point_str(p)
        format("%.4f,%.4f ", cal_x(p.x), cal_y(p.y))
      end

      # Mirror libemf2svg's clipset_draw: emits " clip-path=\"url(#clip-N)\" "
      # only if a clip is currently set. Note the leading and trailing space.
      def clip_path_attr_string
        return "" unless @dc.clip_id

        " clip-path=\"url(#clip-#{@dc.clip_id})\" "
      end

      # Mirror libemf2svg's fill_draw. Emits fill-rule prefix (depending on
      # brush style — see note below) then the fill attribute. Sets
      # @last_fill_set so the caller can decide whether to add fallback
      # `fill="none"`.
      #
      # Quirk: in C, the first switch on fill_mode overlaps with brush style
      # constants — U_BS_NULL(1) matches U_ALTERNATE(1) → "evenodd", and
      # U_BS_HATCHED(2) matches U_WINDING(2) → "nonzero". Other brush styles
      # produce a single space. We replicate this exactly.
      def emit_fill_draw
        brush = @dc.brush
        @last_fill_set = false
        case brush.style
        when Brush::SOLID
          @builder.raw(" ")
          @builder.raw(fill_color_attr(brush))
          @last_fill_set = true
        when Brush::NULL
          @builder.raw("fill=\"none\" ")
          @last_fill_set = true
        when Brush::HATCHED
          @hatch_counter ||= 0
          @hatch_counter += 1
          id = "hatch-#{@hatch_counter}"
          emit_hatch_pattern(id, brush.hatch, brush.color, @dc.bk_color, @dc.bk_mode)
          @builder.raw("fill-rule=\"nonzero\" fill=\"url(##{id})\" ")
          @last_fill_set = true
        else
          @builder.raw(" ")
          @builder.raw(fill_color_attr(brush))
          @last_fill_set = true
        end
      end

      def fill_color_attr(brush)
        "fill=\"#{brush.color.to_hex}\" "
      end

      # Mirror libemf2svg's stroke_draw. Emits stroke attrs depending on pen
      # type (NULL/COSMETIC/GEOMETRIC) and dash style. Does NOT add a leading
      # space — the caller is responsible for spacing.
      def emit_stroke_draw
        pen = @dc.pen
        @last_stroke_set = false
        style = pen.style

        if (style & 0xFF) == Pen::NULL
          if @dc.brush.style != Brush::NULL
            @builder.raw("stroke-width=\"1px\" stroke=\"#{@dc.brush.color.to_hex}\" ")
          else
            @builder.raw("stroke=\"none\" stroke-width=\"0.0\" ")
          end
          @last_stroke_set = true
          return
        end

        # Color then width (C order: color_stroke then width_stroke)
        @builder.raw("stroke=\"#{pen.color.to_hex}\" ")
        emit_width_stroke(pen.width)
        @last_stroke_set = true

        # Dash style
        unit_stroke = (pen.width || 1) * @scaling
        dash_len = unit_stroke * 5
        dot_len = unit_stroke
        case style & 0xFF
        when Pen::DASH
          @builder.raw(format("stroke-dasharray=\"%.4f,%.4f\" ", dash_len, dash_len))
        when Pen::DOT
          @builder.raw(format("stroke-dasharray=\"%.4f,%.4f\" ", dot_len, dot_len))
        when Pen::DASHDOT
          @builder.raw(format("stroke-dasharray=\"%.4f,%.4f,%.4f,%.4f\" ",
                              dash_len, dash_len, dot_len, dash_len))
        when Pen::DASHDOTDOT
          @builder.raw(format("stroke-dasharray=\"%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\" ",
                              dash_len, dash_len, dot_len, dot_len, dot_len, dash_len))
        end

        # Line cap (bits 8-11)
        case style & 0x0F00
        when 0x0000 then @builder.raw(" stroke-linecap=\"round\" ") # PS_ENDCAP_ROUND default
        when 0x0100 then @builder.raw(" stroke-linecap=\"square\" ")
        when 0x0200 then @builder.raw(" stroke-linecap=\"butt\" ")
        end

        # Line join (bits 12-15)
        case style & 0xF000
        when 0x0000 then @builder.raw(" stroke-linejoin=\"round\" ") # PS_JOIN_ROUND default
        when 0x1000 then @builder.raw(" stroke-linejoin=\"bevel\" ")
        when 0x2000
          @builder.raw(" stroke-linejoin=\"miter\" ")
          if @dc.miter_limit
            @builder.raw(format(" stroke-miterlimit=\"%.4f\" ", @scaling * @dc.miter_limit))
          end
        end
      end

      # Mirror libemf2svg's width_stroke: tmp_w = scaleX(width); if (tmp_w/scaling)<1
      # emit "1px", else emit the scaled width.
      def emit_width_stroke(width)
        w = [width.to_i, 1].max
        tmp_w = scale_dim_x(w)
        if (tmp_w / @scaling) < 1.0
          @builder.raw("stroke-width=\"1px\" ")
        else
          @builder.raw(format("stroke-width=\"%.4f\" ", tmp_w))
        end
      end

      HATCH_PATTERNS = {
        0 => [%w[M0,4 L8,4], []],                                    # HS_HORIZONTAL
        1 => [%w[M4,0 L4,8], []],                                    # HS_VERTICAL
        2 => [%w[M0,8 L8,0], []],                                    # HS_FDIAGONAL
        3 => [%w[M0,0 L8,8], []],                                    # HS_BDIAGONAL
        4 => [%w[M0,4 L8,4 M4,0 L4,8], []],                          # HS_CROSS
        5 => [%w[M0,8 L8,0 M0,0 L8,8], []]                           # HS_DIAGCROSS
      }.freeze

      def fill_attrs
        brush = @dc.brush
        return { "fill" => "none" }.merge(clip_attrs) if brush.null?

        if brush.style == 2 # BS_HATCHED
          @hatch_counter ||= 0
          @hatch_counter += 1
          id = "hatch-#{@hatch_counter}"
          emit_hatch_pattern(id, brush.hatch, brush.color, @dc.bk_color, @dc.bk_mode)
          return { "fill" => "url(##{id})" }.merge(clip_attrs)
        end

        { "fill" => brush.color.to_hex }.merge(clip_attrs)
      end

      def emit_hatch_pattern(id, hatch_style, fg_color, bk_color, bk_mode)
        lines = HATCH_PATTERNS[hatch_style] || HATCH_PATTERNS[0]
        bk = bk_mode == 2 ? bk_color.to_hex : "none"
        fg = fg_color.to_hex
        @builder.tag("defs") do
          @builder.tag("pattern", { "id" => id, "width" => 8, "height" => 8,
                                    "patternUnits" => "userSpaceOnUse" }) do
            @builder.tag("rect", { "width" => 8, "height" => 8, "fill" => bk }, single: true)
            lines.each do |d|
              @builder.tag("path", { "d" => d, "stroke" => fg, "stroke-width" => 1 }, single: true)
            end
          end
        end
      end

      def stroke_attrs
        pen = @dc.pen
        style = pen.style

        # NULL pen: libemf2svg falls back to 1px fill-color border
        # (not stroke="none") unless fill is also null
        if (style & 0xFF) == Pen::NULL
          return { "stroke" => "none", "stroke-width" => "0.0" }.merge(clip_attrs) if @dc.brush.null?

          return { "stroke-width" => "1px",
                   "stroke" => @dc.brush.color.to_hex }.merge(clip_attrs)

        end

        w = [pen.width, 1].max
        attrs = { "stroke" => pen.color.to_hex, "stroke-width" => w }

        # Line style (bits 0-7)
        dash_len = w * 5
        dot_len = w
        case style & 0xFF
        when Pen::DASH
          attrs["stroke-dasharray"] = format("%.4f,%.4f", dash_len, dash_len)
        when Pen::DOT
          attrs["stroke-dasharray"] = format("%.4f,%.4f", dot_len, dot_len)
        when Pen::DASHDOT
          attrs["stroke-dasharray"] = format("%.4f,%.4f,%.4f,%.4f", dash_len, dash_len, dot_len, dash_len)
        when Pen::DASHDOTDOT
          attrs["stroke-dasharray"] = format("%.4f,%.4f,%.4f,%.4f,%.4f,%.4f", dash_len, dash_len, dot_len, dot_len, dot_len, dash_len)
        end

        # Line cap (bits 8-11)
        case style & 0x0F00
        when 0x0000 then attrs["stroke-linecap"] = "round" # PS_ENDCAP_ROUND default
        when 0x0100 then attrs["stroke-linecap"] = "square"
        when 0x0200 then attrs["stroke-linecap"] = "butt" # PS_ENDCAP_FLAT
        end

        # Line join (bits 12-15)
        case style & 0xF000
        when 0x0000 then attrs["stroke-linejoin"] = "round" # PS_JOIN_ROUND default
        when 0x1000 then attrs["stroke-linejoin"] = "bevel"
        when 0x2000
          attrs["stroke-linejoin"] = "miter"
          attrs["stroke-miterlimit"] = format("%.4f", @dc.miter_limit) if @dc.miter_limit
        end

        attrs.merge(clip_attrs)
      end

      def fill_rule_attr
        @dc.poly_fill_mode == 2 ? "nonzero" : "evenodd"
      end

      # Scale factors matching libemf2svg's point_cal switch on MapMode.
      def sf_x
        case @dc.map_mode
        when 1 then 1.0
        when 2 then @px_per_mm * 0.1
        when 3 then @px_per_mm * 0.01
        when 4 then @px_per_mm * 0.01 * 25.4
        when 5 then @px_per_mm * 0.001 * 25.4
        when 6 then @px_per_mm / 1440.0 * 25.4
        when 7, 8
          if extents_set?
            @dc.viewport_ext[0].to_f / @dc.window_ext[0]
          else
            1.0
          end
        else
          1.0
        end
      end

      def sf_y
        case @dc.map_mode
        when 1 then 1.0
        when 2 then @px_per_mm * 0.1 * -1
        when 3 then @px_per_mm * 0.01 * -1
        when 4 then @px_per_mm * 0.01 * 25.4 * -1
        when 5 then @px_per_mm * 0.001 * 25.4 * -1
        when 6 then @px_per_mm / 1440.0 * 25.4 * -1
        when 7 # ISOTROPIC: same as sf_x
          sf_x
        when 8 # ANISOTROPIC
          if extents_set?
            @dc.viewport_ext[1].to_f / @dc.window_ext[1]
          else
            @fix_y ? -1.0 : 1.0
          end
        else
          1.0
        end
      end

      def extents_set?
        wx, = @dc.window_ext
        vx, = @dc.viewport_ext
        !wx.nil? && wx != 0 && !vx.nil? && vx != 0
      end

      def maybe_flip_y(y)
        cal_y(y)
      end

      def emit_transform_group(matrix)
        # Mirror libemf2svg's transform_draw: close previous transform group
        # before opening new one, emit `<g transform="matrix(...)">\n`,
        # with eDx/eDy passed through scaleX/scaleY (sign-preserving).
        if @open_groups.positive?
          @builder.rawln("</g>")
          @open_groups -= 1
        end
        dx_scaled = matrix.dx * sf_x * @scaling
        dy_scaled = matrix.dy * sf_y * @scaling
        @builder.rawln(format("<g transform=\"matrix(%.4f %.4f %.4f %.4f %.4f %.4f)\">",
                              matrix.m11, matrix.m12,
                              matrix.m21, matrix.m22,
                              dx_scaled, dy_scaled))
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
