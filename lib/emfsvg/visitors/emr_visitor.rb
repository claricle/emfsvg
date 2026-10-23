# frozen_string_literal: true

require "bigdecimal"
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
        Emf::Emr::Binary::Records::PolyBezierTo => :visit_poly_bezier_to,
        Emf::Emr::Binary::Records::PolyBezierTo16 => :visit_poly_bezier_to16,
        Emf::Emr::Binary::Records::PolylineTo => :visit_polyline_to,
        Emf::Emr::Binary::Records::PolylineTo16 => :visit_polyline_to16,
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
        Emf::Emr::Binary::Records::SmallTextOut => :visit_small_text_out,
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
        Emf::Emr::Binary::Records::SelectClipPath => :visit_select_clip_path,
        Emf::Emr::Binary::Records::GradientFill => :visit_gradient_fill,
        Emf::Emr::Binary::Records::FillRgn => :visit_fill_rgn,
        Emf::Emr::Binary::Records::FrameRgn => :visit_frame_rgn,
        Emf::Emr::Binary::Records::InvertRgn => :visit_invert_rgn,
        Emf::Emr::Binary::Records::PaintRgn => :visit_paint_rgn
      }.freeze

      # Output-space mapping shared by every record: the bounds-to-image
      # scale, the reference origin and the device pixels per millimetre.
      Frame = Struct.new(:scaling, :ref_x, :ref_y, :px_per_mm, keyword_init: true) do
        def initialize(scaling: 1.0, ref_x: 0.0, ref_y: 0.0, px_per_mm: 1.0)
          super
        end
      end

      def initialize(builder, dc, object_table, transform_stack, bounds, fix_y, options,
                     frame: Frame.new, path_actions: {}, path_transforms: {})
        @builder = builder
        @dc = dc
        @object_table = object_table
        @transform_stack = transform_stack
        @bounds = bounds
        @fix_y = fix_y
        @options = options
        @scaling = frame.scaling
        @ref_x = frame.ref_x
        @ref_y = frame.ref_y
        @px_per_mm = frame.px_per_mm
        @path_actions = path_actions
        @path_transforms = path_transforms
        @current_x = 0
        @current_y = 0
        @path_d = nil
        @last_path_d = nil
        @open_groups = 0
        @in_path = false
        @current_record_idx = nil
        @current_path_begin_idx = nil
        # Pattern-brush image library. Keyed by the raw DIB bytes (BmpSrc +
        # cbBits) so identical DIBs share the same image_id, mirroring
        # libemf2svg's image_library_find/image_library_add.
        @image_library = {}
        @next_image_id = 1
        @glyph_mapper = GlyphIndexMapper.new
      end

      attr_reader :current_x, :current_y, :open_groups

      attr_accessor :current_record_idx

      def open_group_count
        @open_groups
      end

      # The Emf wire-record-adapter calls this. Dispatch by wire class.
      def visit_emr_wire_record(adapter)
        klass = RecordAccess.wire_class(adapter)
        method_name = HANDLERS[klass]
        if method_name
          send(method_name, RecordAccess.fields(adapter, klass))
        elsif @options.verbose
          warn "emfsvg: no handler for #{klass.name&.split('::')&.last}"
        end
      rescue ParseError
        raise
      rescue StandardError => e
        raise unless @options.verbose

        warn "emfsvg: handler #{method_name} raised #{e.class}: #{e.message}"
      end

      def flush_open_groups
        @open_groups.times { @builder.rawln("</g>") }
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
        [7, 8].include?(@dc.map_mode) # ISOTROPIC or ANISOTROPIC
      end

      def scale_dim_x(w)
        w * sf_x * @scaling
      end

      def scale_dim_y(h)
        # libemf2svg's scaleY preserves sign (no .abs). Negative raw heights
        # with negative sf_y produce positive output, matching C.
        h * sf_y * @scaling
      end

      # FormatHelpers provides fmt and fmt_xy as module functions.
      # The visitor delegates to them so handler code reads cleanly.
      def fmt(n)
        FormatHelpers.fmt(n)
      end

      def fmt_xy(x, y)
        FormatHelpers.fmt_xy(x, y)
      end

      # Record fields come back from the parser as BinData primitives, or as
      # plain numbers from a value view. Device context state is compared
      # against integer constants on every drawn point, and each such
      # comparison on a BinData value goes through BinData::Base#==. Unwrap
      # once when the state is set instead.
      def int(value)
        value.is_a?(Numeric) ? value : value.snapshot
      end

      # C integer division truncates toward zero; Ruby's Integer#/ floors.
      # For negative operands the results differ (e.g. -333/2: C=-166,
      # Ruby=-167). This helper replicates C's truncation semantics.
      def c_int_div(a, b)
        (a.to_f / b).truncate
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
        @dc.bk_mode = int(wire.bk_mode)
      end

      def visit_set_map_mode(wire)
        @dc.map_mode = int(wire.map_mode)
      end

      def visit_set_rop2(wire)
        # ROP2 mostly ignored by SVG (we are not a raster engine).
      end

      def visit_set_poly_fill_mode(wire)
        @dc.poly_fill_mode = int(wire.poly_fill_mode)
      end

      def visit_set_text_align(wire)
        @dc.text_align = int(wire.text_align_mode)
      end

      def visit_set_stretch_blt_mode(wire)
        @dc.stretch_mode = int(wire.stretch_mode)
      end

      def visit_save_dc(_wire)
        @transform_stack.push(@dc)
      end

      def visit_restore_dc(wire)
        snapshot = @transform_stack.restore(wire.saved_dc)
        @dc = snapshot ? snapshot.dup : @dc
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
        0 => %i[brush white],   # WHITE_BRUSH
        1 => %i[brush ltgray],  # LTGRAY_BRUSH
        2 => %i[brush gray],    # GRAY_BRUSH
        3 => %i[brush dkgray],  # DKGRAY_BRUSH
        4 => %i[brush black],   # BLACK_BRUSH
        5 => %i[brush null],    # NULL_BRUSH
        6 => %i[pen white],     # WHITE_PEN
        7 => %i[pen black],     # BLACK_PEN
        8 => %i[pen null]       # NULL_PEN
      }.freeze

      STOCK_BRUSH_COLORS = {
        white: ColorRGB.new(0xFF, 0xFF, 0xFF),
        ltgray: ColorRGB.new(0xC0, 0xC0, 0xC0),
        gray: ColorRGB.new(0x80, 0x80, 0x80),
        dkgray: ColorRGB.new(0x40, 0x40, 0x40),
        black: ColorRGB.new(0x00, 0x00, 0x00)
      }.freeze

      def visit_select_object(wire)
        ih = int(wire.ih_object)

        # Stock object?
        if ih.anybits?(STOCK_OBJECT_FLAG)
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
          @dc.brush = if variant == :null
                        Brush.new(style: Brush::NULL,
                                  color: Emf::Model::Geometry::Color.white)
                      else
                        Brush.new(style: Brush::SOLID,
                                  color: STOCK_BRUSH_COLORS[variant].to_color)
                      end
        when :pen
          @dc.pen = if variant == :null
                      Pen.new(style: Pen::NULL, width: 1,
                              color: Emf::Model::Geometry::Color.black)
                    else
                      Pen.new(style: Pen::SOLID, width: 1,
                              color: STOCK_BRUSH_COLORS[variant].to_color)
                    end
        end
      end

      def visit_delete_object(wire)
        @object_table.delete(int(wire.ih_object))
      end

      def visit_create_pen(wire)
        pen = Pen.new(
          style: int(wire.pen_style),
          width: int(wire.width.x),
          color: Emf::Model::Geometry::Color.from_wire(wire.color)
        )
        @object_table.store(int(wire.ih_pen), :pen, pen)
      end

      def visit_create_brush_indirect(wire)
        brush = Brush.new(
          style: int(wire.brush_style),
          color: Emf::Model::Geometry::Color.from_wire(wire.color),
          hatch: int(wire.brush_hatch)
        )
        @object_table.store(int(wire.ih_brush), :brush, brush)
      end

      def visit_set_window_org_ex(wire)
        @dc.window_org = [int(wire.origin.x), int(wire.origin.y)]
      end

      def visit_set_window_ext_ex(wire)
        @dc.window_ext = [int(wire.extent.cx), int(wire.extent.cy)]
        @dc.window_ext_set = true
      end

      def visit_set_viewport_org_ex(wire)
        @dc.viewport_org = [int(wire.origin.x), int(wire.origin.y)]
      end

      def visit_set_viewport_ext_ex(wire)
        @dc.viewport_ext = [int(wire.extent.cx), int(wire.extent.cy)]
        @dc.viewport_ext_set = true
      end

      def visit_move_to_ex(wire)
        @current_x = int(wire.origin.x)
        @current_y = int(wire.origin.y)
        return unless @in_path

        # In path: emit `M X,Y ` directly to the open d-string.
        @builder.raw("M ")
        @builder.raw(point_str(wire.origin))
      end

      def visit_line_to(wire)
        if @in_path
          # In path: emit `L X,Y ` to the open d-string, no wrapping.
          @builder.raw("L ")
          @builder.raw(fmt_xy(cal_x(int(wire.origin.x)), cal_y(int(wire.origin.y))))
          @current_x = int(wire.origin.x)
          @current_y = int(wire.origin.y)
          return
        end

        # Standalone LineTo (not in path): full <path> element via endPathDraw.
        # C's startPathDraw creates U_POINT (int32) from cur_x/cur_y,
        # truncating any fractional part before point_cal. We must match.
        d = "M #{fmt(cal_x(@current_x.to_i))},#{fmt(cal_y(@current_y.to_i))} "
        d << "L #{fmt(cal_x(int(wire.origin.x)))},#{fmt(cal_y(int(wire.origin.y)))} "
        emit_path_element(d, closed: false, leading_fill_space: true)
        @current_x = int(wire.origin.x)
        @current_y = int(wire.origin.y)
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
        geom = "x=\"#{fmt(lt_x)}\" y=\"#{fmt(lt_y)}\" width=\"#{fmt(dim_x)}\" height=\"#{fmt(dim_y)}\""
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
        geom = "cx=\"#{fmt(cx)}\" cy=\"#{fmt(cy)}\" rx=\"#{fmt(rx)}\" ry=\"#{fmt(ry)}\""
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
        geom = "x=\"#{fmt(lt_x)}\" y=\"#{fmt(lt_y)}\" width=\"#{fmt(dim_x)}\" height=\"#{fmt(dim_y)}\" " \
               "rx=\"#{fmt(rx)}\" ry=\"#{fmt(ry)}\""
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

      # PolylineTo continues from current position — no M for first point,
      # all L. Matches C's polyline_draw with ispolygon=false.
      def visit_polyline_to(wire)
        emit_polyline_to_common(wire.aptl.to_a)
      end

      def visit_polyline_to16(wire)
        emit_polyline_to_common(wire.apts.to_a)
      end

      def emit_polyline_to_common(points)
        return if points.empty?

        if @in_path
          points.each do |p|
            @builder.raw("L ")
            @builder.raw(point_str(p))
          end
          @current_x = int(points.last.x)
          @current_y = int(points.last.y)
          return
        end

        # Standalone PolylineTo (rare): emit a path starting at cur.
        d = "M #{fmt(cal_x(@current_x.to_i))},#{fmt(cal_y(@current_y.to_i))} "
        points.each do |p|
          d << "L "
          d << point_str(p)
        end
        emit_path_element(d, closed: false, leading_fill_space: true)
        @current_x = int(points.last.x)
        @current_y = int(points.last.y)
      end

      def visit_poly_bezier(wire)
        emit_poly_bezier_common(wire.aptl.to_a, starting_point: true)
      end

      def visit_poly_bezier16(wire)
        emit_poly_bezier_common(wire.apts.to_a, starting_point: true)
      end

      # PolyBezierTo continues from current position — no starting M.
      def visit_poly_bezier_to(wire)
        emit_poly_bezier_common(wire.aptl.to_a, starting_point: false)
      end

      def visit_poly_bezier_to16(wire)
        emit_poly_bezier_common(wire.apts.to_a, starting_point: false)
      end

      # Matches cubic_bezier_draw / cubic_bezier16_draw.
      # startPathDraw emits `M cur_x,cur_y ` (from the device context's
      # current position). If starting_point is true (PolyBezier, not To),
      # an additional `M point[0]` is emitted before the C commands.
      #
      # libemf2svg iterates over every point starting at `startingPoint`
      # and emits a "C " prefix each time (i mod 3) == ctrl1; the next two
      # points are appended without re-emitting "C ". This works even with
      # fewer than 4 points (a single bezier curve) — there's no minimum.
      def emit_poly_bezier_common(points, starting_point:)
        return if points.empty?

        if @in_path
          if starting_point && points.first
            @builder.raw("M ")
            @builder.raw(point_str(points.first))
          end
          emit_bezier_points(points, starting_point: starting_point)
          if points.last
            @current_x = int(points.last.x)
            @current_y = int(points.last.y)
          end
          return
        end

        d = "M #{fmt(cal_x(@current_x.to_i))},#{fmt(cal_y(@current_y.to_i))} "
        if starting_point && points.first
          d << "M "
          d << point_str(points.first)
        end
        d << bezier_points_d(points, starting_point: starting_point)
        emit_path_element(d, closed: false, leading_fill_space: true)
        return unless points.last

        @current_x = int(points.last.x)
        @current_y = int(points.last.y)
      end

      # Emit "C p1 p2 p3 C p4 p5 p6 ..." matching cubic_bezier*_draw's
      # loop. Each iteration emits "C " then the next 3 points; trailing
      # incomplete triples are silently dropped (matches C, which only
      # emits "C " on the ctrl1 index and ignores dangling points).
      def emit_bezier_points(points, starting_point:)
        ctrls = starting_point ? points[1..] : points
        ctrls.each_slice(3) do |c1, c2, endpt|
          next if [c1, c2, endpt].any?(&:nil?)

          @builder.raw("C ")
          @builder.raw(point_str(c1))
          @builder.raw(point_str(c2))
          @builder.raw(point_str(endpt))
        end
      end

      def bezier_points_d(points, starting_point:)
        ctrls = starting_point ? points[1..] : points
        d = +""
        ctrls.each_slice(3) do |c1, c2, endpt|
          next if [c1, c2, endpt].any?(&:nil?)

          d << "C "
          d << point_str(c1)
          d << point_str(c2)
          d << point_str(endpt)
        end
        d
      end

      def visit_begin_path(_wire)
        if @in_path
          @pending_path_action = @path_actions[@current_record_idx] || :end
          return
        end

        @current_path_begin_idx = @current_record_idx
        # Apply deferred wtBefore transform (from Modify/SetWorldTransform
        # records that occurred after drawing inside this path). Mirrors
        # libemf2svg's U_EMRBEGINPATH_draw which calls transform_set +
        # transform_draw if pathStack.wtBeforeSet is true.
        apply_path_transform(:wt_before)
        @path_start_pos = @builder.to_s.bytesize
        @builder.raw("<path d=\"")
        @last_path_d = +""
        @in_path = true
        @pending_path_action = @path_actions[@current_record_idx] || :end
      end

      def visit_end_path(_wire)
        @in_path = false
        finish_pending_path(@pending_path_action)
        # Apply deferred wtAfter transform (from transforms that occurred
        # before drawing inside this path). Mirrors libemf2svg's
        # U_EMRENDPATH_draw which calls transform_set + transform_draw
        # after emitting the path element if pathStack.wtAfterSet is true.
        apply_path_transform(:wt_after)
        @current_path_begin_idx = nil
      end

      def visit_fill_path(_wire)
        # FillPath after EndPath: in C this is a no-op (work done at EndPath).
        # If we never saw EndPath (FillPath directly closes path), close now.
        return unless @in_path

        @in_path = false
        finish_pending_path(:fill)
      end

      def visit_stroke_path(_wire)
        return unless @in_path

        @in_path = false
        finish_pending_path(:stroke)
      end

      def visit_stroke_and_fill_path(_wire)
        return unless @in_path

        @in_path = false
        finish_pending_path(:stroke_fill)
      end

      def visit_abort_path(_wire)
        @in_path = false
        @pending_path_action = :abort
      end

      # Emit the closing quote + stroke/fill attrs for a path opened by
      # visit_begin_path. Mode is one of: :end, :fill, :stroke, :stroke_fill.
      def finish_pending_path(mode)
        @last_fill_set = false
        @last_stroke_set = false
        # Capture the d-string content for SelectClipPath.
        # Everything between `<path d="` (at @path_start_pos + 9) and the
        # closing `"` that finish_pending_path is about to emit.
        if @path_start_pos
          d_start = @path_start_pos + 9 # length of `<path d="`
          @last_path_d = @builder.to_s[d_start...].force_encoding("ASCII-8BIT")
        end
        @builder.raw("\" ")
        case mode
        when :fill
          emit_fill_draw
        when :stroke
          emit_stroke_draw
        when :stroke_fill
          emit_fill_draw
          emit_stroke_draw
        end
        @builder.raw("fill=\"none\" ") unless @last_fill_set
        @builder.raw("stroke=\"none\" ") unless @last_stroke_set
        @builder.rawln("/>")
      end

      def visit_close_figure(_wire)
        @builder.raw("Z ") if @in_path
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

      # Apply a deferred path transform (wtBefore at BeginPath, wtAfter at
      # EndPath). Mirrors libemf2svg's pathStack.wtBefore/wtAfter handling
      # which calls transform_set followed by transform_draw.
      def apply_path_transform(key)
        entry = @path_transforms[@current_path_begin_idx]
        return unless entry

        pt = entry[key]
        return unless pt

        @dc.world_transform = if pt.mode.nil? || pt.mode.zero?
                                pt.matrix
                              else
                                case pt.mode
                                when 1 then Emf::Model::Geometry::Matrix.identity
                                when 2 then multiply_matrix(pt.matrix, @dc.world_transform)
                                when 3 then multiply_matrix(@dc.world_transform, pt.matrix)
                                else pt.matrix
                                end
                              end
        emit_transform_group(@dc.world_transform)
      end

      def visit_set_miter_limit(wire)
        limit = wire.miter_limit.to_f
        # libemf2svg-produced EMFs store this field as the integer payload's
        # float bit pattern, while native SetMiterLimit records store a float.
        limit = [limit].pack("f").unpack1("L<") if limit.abs < 1.1754943508222875e-38
        @dc.miter_limit = limit
      end

      def visit_comment(_wire); end

      def visit_set_pixel_v(_wire)
        # FLAG_IGNORED in libemf2svg — emits nothing.
      end

      def visit_create_font_indirect_w(wire)
        body = wire.body.to_s
        font = parse_logfont(body, utf16: true)
        @object_table.store(int(wire.ih_object), :font, font)
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

        height = body.unpack1("l<")
        _width = body.unpack("l<", offset: 4)[0]
        # C remainder preserves the dividend sign (so -2700 stays -2700).
        escapement = body.unpack("l<", offset: 8)[0].remainder(3600)
        weight = body.unpack("l<", offset: 16)[0]
        italic = body.getbyte(20) != 0
        underline = body.getbyte(21) != 0
        strikeout = body.getbyte(22) != 0
        charset = body.getbyte(23)
        face_name = parse_logfont_face_name(body, utf16: utf16)
        Font.new(face_name: face_name, height: height, weight: weight,
                 italic: italic, underline: underline, strikeout: strikeout,
                 escapement: escapement, charset: charset)
      rescue StandardError
        Font.default
      end

      def visit_ext_text_out_w(wire)
        emit_ext_text(wire, utf16: true)
      end

      def visit_ext_text_out_a(wire)
        emit_ext_text(wire, utf16: false)
      end

      # EMRSMALLTEXTOUT: simpler than EXTTEXTOUT — fixed-position Dest,
      # no DX array, text follows optional RECTL. Mirrors C's
      # U_EMRSMALLTEXTOUT_draw.
      def visit_small_text_out(wire)
        body = wire.body.to_s
        fu = wire.fu_options.to_i
        # Per MS-EMF 2.3.5.37: ETO_NO_RECT (0x100) UNSET means a U_RECTL
        # (16 bytes) precedes the text. ETO_SMALL_CHARS (0x200) selects
        # 8-bit per char instead of 16-bit.
        text_offset = fu.nobits?(0x100) ? 16 : 0
        small_chars = fu.anybits?(0x200) # ETO_SMALL_CHARS = 0x200
        c_chars = wire.c_chars.to_i
        bytes_per_char = small_chars ? 1 : 2
        text_bytes = body[text_offset, c_chars * bytes_per_char]
        text = decode_text_chars(text_bytes, small_chars: small_chars)
        x = cal_x(wire.x_dest)
        y = cal_y(wire.y_dest)
        font = @dc.font
        font_height = scale_dim_x(font.height.to_i).abs
        @builder.raw("<text ")
        @builder.raw(clip_path_attr_string)
        emit_text_style(font, font_height, x, y)
        @builder.raw(">")
        @builder.raw("<![CDATA[#{text}]]>")
        @builder.rawln("</text>")
      end

      def decode_text_chars(bytes, small_chars:)
        return "" if bytes.nil? || bytes.empty?

        if small_chars
          bytes.force_encoding("CP1252").encode("UTF-8", undef: :replace, replace: "?")
        else
          decode_utf16_text(bytes)
        end
      end

      # Decode glyph-index text via fontconfig + fontisan reverse cmap.
      # Mirrors libemf2svg's fontindex_to_utf8: find font file, build
      # reverse cmap, map each glyph ID to Unicode, reverse for RTL.
      def decode_glyph_indices(string_bytes, n_chars)
        glyph_ids = string_bytes.unpack("v*").first(n_chars)
        font = @dc.font
        result = @glyph_mapper.map(
          glyph_ids,
          font_family: font.face_name,
          weight: font.weight,
          italic: font.italic,
          charset: font.charset
        )
        # libemf2svg's fontindex_to_utf8 returns NULL when the font
        # can't be found, producing empty CDATA. We must NOT fall back
        # to UTF-16 decoding — that would produce wrong characters.
        result || ""
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

      # libemf2svg's U_EMROFFSETCLIPRGN_draw: offsets the current clipRGN
      # by ptlOffset, then calls clip_rgn_draw which generates a NEW
      # clip ID and emits a NEW clipPath def. Without this, the BsdRand
      # sequence diverges from C, causing all subsequent clip IDs to be
      # wrong.
      def visit_offset_clip_rgn(wire)
        return unless @dc.clip_region

        dx = wire.ptl_offset.x
        dy = wire.ptl_offset.y
        region = @dc.clip_region
        if region.bounds
          b = region.bounds
          @dc.clip_region = ClipRegion.new(
            bounds: Emf::Model::Geometry::Rect.new(
              left: b.left + dx, top: b.top + dy,
              right: b.right + dx, bottom: b.bottom + dy
            )
          )
        elsif region.path_d
          @dc.clip_region = ClipRegion.new(path_d: region.path_d)
        end
        emit_clip_def(@dc.clip_region)
      end

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
        # C maps: U_AD_CLOCKWISE (2) → arcdir=1, U_AD_COUNTERCLOCKWISE (1) → arcdir=-1
        case wire.arc_direction
        when 2 then @dc.arc_direction = 1   # AD_CLOCKWISE
        when 1 then @dc.arc_direction = -1  # AD_COUNTERCLOCKWISE
        end
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

        # arcdir: 1 = CLOCKWISE (sweep=large=1), -1 = CCW (sweep=large=0).
        # Default (0) is treated as not-positive, so sweep=large=0.
        arcdir = @dc.arc_direction || 0
        sweep_flag = arcdir.positive? ? 1 : 0
        large_arc_flag = arcdir.positive? ? 1 : 0

        start_rad = start_angle * Math::PI / 180.0
        end_rad = (start_angle + sweep_angle) * Math::PI / 180.0
        sx_raw = (r_raw * Math.cos(start_rad)) + cx_raw
        sy_raw = (r_raw * Math.sin(start_rad)) + cy_raw
        ex_raw = (r_raw * Math.cos(end_rad)) + cx_raw
        ey_raw = (r_raw * Math.sin(end_rad)) + cy_raw

        d = +"M "
        d << fmt_xy(cal_x(@current_x.to_i), cal_y(@current_y.to_i))
        d << "M "
        d << fmt_xy(cal_x(sx_raw), cal_y(sy_raw))
        d << "A "
        d << fmt_xy(cal_x(r_raw), cal_y(r_raw))
        d << "0 "
        d << "#{large_arc_flag} #{sweep_flag} "
        d << fmt_xy(cal_x(ex_raw), cal_y(ey_raw))
        emit_path_element(d, closed: false, leading_fill_space: true)
      end

      # --- Escape and color-management no-ops ---

      def visit_noop(_wire); end
      def visit_draw_escape(_wire); end
      def visit_ext_escape(_wire); end
      def visit_named_escape(_wire); end
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
        register_pattern_brush(wire)
      end

      def visit_create_dib_pattern_brush_pt(wire)
        register_pattern_brush(wire)
      end

      # CreateMonoBrush / CreateDibPatternBrushPt: extract the embedded DIB,
      # emit a <defs><image id="img-N">…<pattern id="img-N-ref">…</defs>
      # block (matching U_EMRCREATEMONOBRUSH_draw + image_library_writer),
      # then store a MONOPATTERN brush in the object table so later fills
      # reference url(#img-N-ref).
      def register_pattern_brush(wire)
        # Wire types calling this (CreateMonoBrush, CreateDibPatternBrushPt)
        # always have off_bmi and off_bits — declared in their bindata
        # layouts. No need for respond_to? duck-typing.

        # The BMI and bitmap data are located at absolute offsets within
        # the EMR record. The wire's `body` field starts after the emr
        # header (8 bytes) + 6 uint32 fixed fields (ih_brush, i_usage,
        # off_bmi, cb_bmi, off_bits, cb_bits = 24 bytes) = offset 32.
        # Convert record-relative offsets to body-relative indices.
        body = wire.body.to_s
        body_bytes = body.bytes

        bmi_start = wire.off_bmi.to_i - 32
        cb_bmi = wire.cb_bmi.to_i
        bits_start = wire.off_bits.to_i - 32
        cb_bits = wire.cb_bits.to_i

        return if bmi_start.negative? || bits_start.negative?
        return if bmi_start + cb_bmi > body_bytes.size
        return if bits_start + cb_bits > body_bytes.size

        bmi_bytes = body_bytes[bmi_start, cb_bmi].pack("C*")
        bits_bytes = body_bytes[bits_start, cb_bits].pack("C*")

        # libemf2svg's image_library_find uses memcmp(BmiSrc, lib->content,
        # cbBits). Since BmiSrc points at the BMI header (cbBmi bytes) and
        # cbBits is the bitmap data size, the comparison actually reads
        # cbBits bytes starting at the BMI — i.e. it spans BMI + the first
        # (cbBits - cbBmi) bytes of bitmap data (or all of bitmap if
        # cbBits < cbBmi, which doesn't happen in practice). Replicate that
        # exact key so identical DIBs dedupe to the same image_id.
        dedup_key = body_bytes[bmi_start, cb_bits].pack("C*")

        # Deduplicate by raw bitmap bytes (image_library_find key).
        image_id = @image_library[dedup_key]
        if image_id.nil?
          image_id = @next_image_id
          @next_image_id += 1
          @image_library[dedup_key] = image_id
          emit_pattern_defs(image_id, bmi_bytes, bits_bytes)
        end

        brush = Brush.new(style: Brush::MONOPATTERN,
                          color: @dc.brush.color,
                          image_id: image_id)
        @object_table.store(int(wire.ih_brush), :brush, brush)
      end

      # Emit <defs><image id="img-N" .../><pattern id="img-N-ref"
      # ...>...</pattern></defs> exactly as libemf2svg's
      # image_library_writer does.
      def emit_pattern_defs(image_id, bmi_bytes, bits_bytes)
        # For 1-bpp MONOCHROME brushes libemf2svg's dib_img_writer is called
        # with assign_mono_colors_from_dc=true, which overrides palette[0]
        # with text_color and palette[1] with bk_color (alpha forced 0xff).
        # Decode with that override so PNG bytes match.
        dib = if bmi_bytes.getbyte(14) == 1 # bit_count == 1
                text = @dc.text_color
                bk = @dc.bk_color
                DibDecoder.decode(bmi_bytes + bits_bytes,
                                  mono_palette: [[text.red, text.green, text.blue, 255],
                                                 [bk.red, bk.green, bk.blue, 255]])
              else
                DibDecoder.decode(bmi_bytes + bits_bytes)
              end
        return unless dib

        png_bytes = PngEncoder.encode(dib.width, dib.height, dib.pixels)
        b64 = [png_bytes].pack("m0")
        ns = ""
        @builder.raw("<#{ns}defs><#{ns}image id=\"img-#{image_id}\" x=\"0\" y=\"0\" ")
        @builder.raw("width=\"#{dib.width}\" height=\"#{dib.height}\" ")
        @builder.raw("xlink:href=\"data:image/png;base64,#{b64}\" ")
        @builder.raw(" preserveAspectRatio=\"none\" />")
        @builder.raw("<#{ns}pattern id=\"img-#{image_id}-ref\" x=\"0\" y=\"0\" ")
        @builder.raw("width=\"#{dib.width}\" height=\"#{dib.height}\" ")
        @builder.raw("patternUnits=\"userSpaceOnUse\" >\n")
        @builder.raw("<#{ns}use id=\"img-#{image_id}-ign\" xlink:href=\"#img-#{image_id}\" />")
        @builder.raw("</#{ns}pattern></#{ns}defs>\n")
      end

      # --- Region operations (TODO 08) ---

      # libemf2svg marks FillRgn/FrameRgn/InvertRgn/PaintRgn as FLAG_IGNORED —
      # they emit nothing. Match that exactly so byte output lines up.
      def visit_fill_rgn(_wire); end

      def visit_frame_rgn(_wire); end

      def visit_invert_rgn(_wire); end

      def visit_paint_rgn(_wire); end

      def visit_ext_create_pen(wire)
        # EMREXTCREATEPEN body layout (after EMR + ihPen) per MS-EMF 2.3.7.9:
        #   offBmi (4), cbBmi (4), offBits (4), cbBits (4),
        #   then EXTLOGPEN32:
        #     elpPenStyle (4), elpWidth (4), elpBrushStyle (4),
        #     elpColor (COLORREF: R,G,B,reserved — 4 bytes),
        #     elpHatch (4), elpNumEntries (4), elpStyleEntry[]
        body = wire.body.to_s
        if body.bytesize >= 32
          pen_style = body.unpack1("V", offset: 16)
          width = body.unpack1("V", offset: 20)
          # COLORREF at body offset 28: low byte is R, then G, then B
          r = body.getbyte(28)
          g = body.getbyte(29)
          b = body.getbyte(30)
          pen = Pen.new(
            style: pen_style,
            width: width,
            color: Emf::Model::Geometry::Color.new(red: r, green: g, blue: b)
          )
          @object_table.store(int(wire.ih_pen), :pen, pen)
        else
          @object_table.store(int(wire.ih_pen), :pen, Pen.new)
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
        # BitBlt with no source bitmap (cb_bits_src == 0) is used as a
        # "fill rectangle with current brush" operation. libemf2svg emits
        # this as <path style="fill:..." d="M x,y L x+w,y L x+w,y+h L x,y+h Z" />
        # when fill_mode is BS_SOLID or BS_MONOPATTERN. For other fill modes
        # (or unsupported raster ops), it emits nothing.
        if wire.cb_bits_src.to_i.zero?
          emit_bitblt_solid_fill(wire)
          return
        end

        # Bitmap present: emit <image> using Dest/cDest (NOT rclBounds) per
        # libemf2svg's U_EMRBITBLT_draw which calls point_cal on Dest and
        # cDest, then reads BMI/bits via offBmiSrc/offBitsSrc.
        emit_image_from_offsets(wire, position_via_point_cal: true)
      end

      def visit_stretch_blt(wire)
        if wire.cb_bits_src.to_i.positive?
          emit_image_from_offsets(wire, position_via_point_cal: true)
          return
        end

        emit_image_from_body(
          wire, wire.rcl_bounds.left, wire.rcl_bounds.top,
          wire.rcl_bounds.right - wire.rcl_bounds.left,
          wire.rcl_bounds.bottom - wire.rcl_bounds.top
        )
      end

      # Emit <image> for BitBlt/StretchBlt records that have explicit
      # offBmiSrc/cbBmiSrc/offBitsSrc/cbBitsSrc fields. Mirrors
      # libemf2svg's U_EMRSTRETCHBLT_draw: locate BMI/bitmap via the
      # offsets, decode, and emit as PNG data URI.
      #
      # libemf2svg uses point_cal for both position AND size (not just
      # position). For StretchBlt this matters because the size in
      # logical units gets transformed by the world matrix; for BitBlt
      # the matrix is usually identity so it doesn't matter.
      def emit_image_from_offsets(wire, position_via_point_cal: false)
        record_bytes = wire.to_binary_s
        rec_size = record_bytes.bytesize
        off_bmi = wire.off_bmi_src.to_i
        cb_bmi = wire.cb_bmi_src.to_i
        off_bits = wire.off_bits_src.to_i
        cb_bits = wire.cb_bits_src.to_i
        return if off_bmi.zero? || off_bits.zero?
        return if off_bmi + cb_bmi > rec_size
        return if off_bits + cb_bits > rec_size

        bmi = record_bytes[off_bmi, cb_bmi]
        bits = record_bytes[off_bits, cb_bits]
        result = DibDecoder.decode(bmi + bits, bits_offset: cb_bmi)
        return unless result

        if position_via_point_cal
          # StretchBlt path: emit width/height/x/y in C's exact order
          # using point_cal for both size and position.
          size_x = cal_x(wire.cx_dest.to_i)
          size_y = cal_y(wire.cy_dest.to_i)
          pos_x = cal_x(wire.x_dest.to_i)
          pos_y = cal_y(wire.y_dest.to_i)
          @builder.raw("<image width=\"#{fmt(size_x)}\" height=\"#{fmt(size_y)}\" ")
          @builder.raw("x=\"#{fmt(pos_x)}\" y=\"#{fmt(pos_y)}\" ")
          @builder.raw(clip_path_attr_string)
          @builder.raw("xlink:href=\"")
          @builder.raw(build_image_href(result))
          @builder.raw("\" />\n")
        else
          x = cal_x(wire.x_dest.to_i)
          y = maybe_flip_y(cal_y(wire.y_dest.to_i))
          w = scale_dim_x(wire.cx_dest.to_i)
          h = scale_dim_y(wire.cy_dest.to_i)
          attrs = {
            "x" => x, "y" => y, "width" => w, "height" => h,
            "xlink:href" => build_image_href(result), "preserveAspectRatio" => "none"
          }
          @builder.tag("image", attrs, single: true)
        end
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
        return unless @last_path_d && !@last_path_d.empty?

        @dc.clip_region = ClipRegion.new(path_d: @last_path_d.dup)
        emit_clip_def(@dc.clip_region)
      end

      # libemf2svg marks U_EMRGRADIENTFILL_draw as FLAG_IGNORED — emits nothing.
      def visit_gradient_fill(_wire); end

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
          x_left = cal_x(b.left)
          x_right = cal_x(b.right)
          y_top = cal_y(b.top)
          y_bottom = cal_y(b.bottom)
          d = +"M "
          FormatHelpers.append_xy(d, x_left, y_top)
          d << "L "
          FormatHelpers.append_xy(d, x_right, y_top)
          d << "L "
          FormatHelpers.append_xy(d, x_right, y_bottom)
          d << "L "
          FormatHelpers.append_xy(d, x_left, y_bottom)
          d << "L "
          FormatHelpers.append_xy(d, x_left, y_top)
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
        return nil if body.bytesize < LOGFONT_FACE_NAME_OFFSET + 2

        raw = body.bytes[LOGFONT_FACE_NAME_OFFSET, LOGFONT_FACE_NAME_MAX_BYTES]
        return nil unless raw

        if utf16
          # libemf2svg calls U_Utf16leToUtf8 with the FULL 32-char (64-byte)
          # buffer — it does NOT stop at the null terminator. If any byte
          # pair in the buffer is not valid UTF-16LE (e.g. a lone surrogate
          # in the unused tail), iconv fails and returns NULL, which means
          # no font-family attribute is emitted. We replicate that bug.
          return nil unless valid_utf16le_pairs?(raw)

          # libemf2svg's iconv then converts ALL 64 bytes (including nulls
          # and trailing junk) into UTF-8. fprintf("%s", ...) then truncates
          # at the first NUL byte. Replicate by encoding the full buffer
          # and truncating at the first NUL.
          decoded = raw.pack("C*").force_encoding("UTF-16LE").encode("UTF-8",
                                                                     undef: :replace,
                                                                     replace: "?")
          if (nul = decoded.index("\0"))
            decoded = decoded[0, nul]
          end
          decoded.empty? ? nil : decoded
        else
          raw.take_while { |b| !b.zero? }.pack("C*").force_encoding("CP1252")
             .encode("UTF-8", undef: :replace, replace: "?")
        end
      rescue StandardError
        nil
      end

      # Replicates iconv's UTF-16LE validation: returns false if any 2-byte
      # pair is a lone surrogate (U+D800..U+DFFF). Buffer length must be even.
      def valid_utf16le_pairs?(bytes)
        return false unless bytes.size.even?

        (0...bytes.size).step(2).each do |i|
          code = bytes[i] | (bytes[i + 1] << 8)
          return false if code.between?(0xD800, 0xDFFF)
        end
        true
      end

      # Decodes the string carried by an EXTTEXTOUT record; "" when the
      # record holds no (in-range) string bytes.
      def ext_text_content(wire, utf16:)
        record_bytes = wire.to_binary_s
        off_string = wire.off_string
        n_chars = wire.n_chars
        return "" unless off_string&.positive? && off_string < record_bytes.bytesize

        string_bytes = record_bytes[off_string, utf16 ? n_chars * 2 : n_chars]
        return "" if string_bytes.nil? || string_bytes.empty?

        if wire.f_options.to_i.anybits?(GlyphIndexMapper::ETO_GLYPH_INDEX)
          decode_glyph_indices(string_bytes, n_chars)
        elsif utf16
          decode_utf16_text(string_bytes)
        else
          cleaned = string_bytes.bytes.map { |b| b > 0x7F ? 0x20 : b }
          cleaned.pack("C*").force_encoding("UTF-8")
        end
      end

      def decode_utf16_text(string_bytes)
        string_bytes.force_encoding("UTF-16LE").encode("UTF-8", undef: :replace, replace: "?")
      rescue Encoding::InvalidByteSequenceError => e
        raise ParseError, e.message, cause: e
      end

      def emit_ext_text(wire, utf16:)
        text = ext_text_content(wire, utf16: utf16)

        # libemf2svg emits the <text> element even when the string is empty.
        x = cal_x(int(wire.ptl_reference.x))
        y = cal_y(int(wire.ptl_reference.y))

        font = @dc.font
        font_height = scale_dim_x(font.height.to_i).abs

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
        @builder.raw("fill=\"#{rgb_hex(@dc.text_color)}\" ")

        orientation = sf_y.positive? ? -1 : 1
        if font.escapement != 0
          # C's integer division truncates toward zero; Ruby's Integer#/ floors.
          # Use float division + truncate to match C exactly for negative values.
          rotation = (orientation.to_f * font.escapement / 10).truncate
          adj_y = y + (font_height * 0.9)
          @builder.raw("transform=\"rotate(#{rotation}, #{fmt(x)}, #{fmt(adj_y)}) " \
                       "translate(0, #{fmt(font_height * 0.9)})\" ")
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
        # libemf2svg checks both U_TA_CENTER (0x06) AND U_TA_CENTER2 (0x04)
        # for "middle" anchor. Mask 0x06 doesn't include 0x04, so handle
        # both explicitly to match C.
        anchor = if align.allbits?(0x06) || align.allbits?(0x04)
                   "middle"
                 elsif align.allbits?(0x02)
                   "end"
                 else
                   "start"
                 end
        @builder.raw("text-anchor=\"#{anchor}\" ")

        # Vertical position: TA_BOTTOM (0x08) or TA_BASELINE (0x18) use Org.y;
        # otherwise add font_height * 0.9.
        y_pos = if align.allbits?(0x18) || (align & 0x18) == 0x08
                  y
                else
                  y + (font_height * 0.9)
                end
        @builder.raw("x=\"#{fmt(x)}\" y=\"#{fmt(y_pos)}\" ")
        @builder.raw("font-size=\"#{fmt(font_height)}\" ")
      end

      def emit_arc(wire, mode:)
        # Mirror libemf2svg's arc_draw. Uses int_el_rad to find the
        # intersection of ptlStart/ptlEnd with the ellipse boundary.
        # Path data: `M cur M startpoint A radii 0 large sweep endpoint [L center Z] [Z]`
        # Closes via endPathDraw (arc) or endFormDraw (chord/pie).
        rcl_left = wire.rcl_box.left
        rcl_top = wire.rcl_box.top
        rcl_right = wire.rcl_box.right
        rcl_bottom = wire.rcl_box.bottom
        radii_x = c_int_div(rcl_right - rcl_left, 2)
        radii_y = c_int_div(rcl_bottom - rcl_top, 2)
        return if radii_x.zero? || radii_y.zero?

        start_pt = int_el_rad(wire.ptl_start, wire.rcl_box)
        end_pt = int_el_rad(wire.ptl_end, wire.rcl_box)

        arcdir = @dc.arc_direction || 1
        sweep_flag = arcdir.positive? ? 1 : 0
        large_arc_flag = arcdir.positive? ? 1 : 0

        d = +"M "
        d << fmt_xy(cal_x(@current_x.to_i), cal_y(@current_y.to_i))
        d << "M "
        d << fmt_xy(cal_x(start_pt[0]), cal_y(start_pt[1]))
        d << "A "
        d << fmt_xy(cal_x(radii_x), cal_y(radii_y))
        d << "0 "
        d << "#{large_arc_flag} #{sweep_flag} "
        d << fmt_xy(cal_x(end_pt[0]), cal_y(end_pt[1]))

        case mode
        when :pie
          center_x = (rcl_right + rcl_left) / 2
          center_y = (rcl_bottom + rcl_top) / 2
          d << "L "
          d << fmt_xy(cal_x(center_x), cal_y(center_y))
          d << "Z "
          emit_path_element_closed(d)
          # C's arc_draw PIE case updates cur_x/cur_y to center via point_draw.
          @current_x = center_x
          @current_y = center_y
        when :chord
          d << "Z "
          emit_path_element_closed(d)
          # Chord: cur_x/cur_y stays at end point.
          @current_x = end_pt[0]
          @current_y = end_pt[1]
        else
          emit_path_element(d, closed: false, leading_fill_space: true)
          # Arc: cur_x/cur_y updated to end point (point_draw_d).
          @current_x = end_pt[0]
          @current_y = end_pt[1]
        end
      end

      # Compute the intersection of a point with the ellipse boundary
      # (mirrors libemf2svg's int_el_rad). Returns [x, y].
      #
      # CRITICAL: C's int_el_rad uses INTEGER division on U_POINTL/U_RECTL
      # values. C integer division truncates toward zero; Ruby's Integer#/
      # floors. For negative sums (e.g. (-161 + -172) / 2), C gives -166
      # but Ruby gives -167 — a 1-pixel offset. We must replicate C's
      # truncation by converting to float and truncating.
      def int_el_rad(point, rect)
        center_x = c_int_div(rect.right + rect.left, 2)
        center_y = c_int_div(rect.bottom + rect.top, 2)
        radii_x = c_int_div(rect.right - rect.left, 2)
        radii_y = c_int_div(rect.bottom - rect.top, 2)
        return [center_x, center_y] if radii_x.zero? || radii_y.zero?

        pt_no_x = point.x.to_f - center_x
        pt_no_y = point.y.to_f - center_y

        if pt_no_x.zero?
          return [center_x, ((pt_no_y.negative? ? -1 : 1) * radii_y) + center_y]
        end
        if pt_no_y.zero?
          return [((pt_no_x.negative? ? -1 : 1) * radii_x) + center_x, center_y]
        end

        slope = pt_no_y / pt_no_x
        isect_x = ((pt_no_x.negative? ? -1 : 1) *
                  Math.sqrt(1 / (((1 / radii_x.to_f)**2) + ((slope / radii_y.to_f)**2)))) +
                  center_x
        isect_y = ((pt_no_y.negative? ? -1 : 1) *
                  Math.sqrt(1 / (((1 / (slope * radii_x.to_f))**2) + ((1 / radii_y.to_f)**2)))) +
                  center_y
        [isect_x, isect_y]
      end

      # Closes a path element using endFormDraw pattern:
      #   `<path d="..." [clipset] stroke fill [fallbacks] />\n`
      # Note the literal ` />` (with leading space) — endFormDraw uses
      # fprintf(" />\n") vs U_EMRPOLYGON_draw's fprintf("/>\n").
      def emit_path_element_closed(d_string)
        @builder.raw("<path ")
        @builder.raw(clip_path_attr_string)
        @builder.raw("d=\"")
        @builder.raw(d_string)
        @builder.raw("\" ")
        emit_stroke_draw
        emit_fill_draw
        emit_unfilled_unstroked
        @builder.raw(" />")
        @builder.newline
      end

      def emit_poly_multi(counts, all_points, closed:, _point_size:)
        return if counts.empty? || all_points.empty?

        # libemf2svg emits ALL sub-polygons in a single <path> element,
        # separated by Z M between sub-polygons. Each sub-polygon ends with
        # `Z `, then the next starts with `M `. The path closes with `Z" `
        # (single Z appended by U_EMRPOLYPOLYGON_draw).
        d = +""
        offset = 0
        last_pt = nil
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
          last_pt = sub_points.last
        end
        return if d.empty?

        if @in_path
          # Inside BeginPath..EndPath: append directly to open d-string.
          # PolyPolygon doesn't add Z (caller does at EndPath/FillPath/etc).
          @builder.raw(d)
        else
          # PolyPolygon (closed) vs PolyPolyline (open) have DIFFERENT
          # attribute orders in C:
          #   PolyPolygon: fill_draw → stroke_draw → fallbacks
          #   PolyPolyline: stroke_draw → unconditional `fill="none"`
          @builder.raw("<path ")
          @builder.raw(clip_path_attr_string)
          @builder.raw("d=\"")
          @builder.raw(d)
          @builder.raw("\" ")
          if closed
            emit_fill_draw
            emit_stroke_draw
            emit_unfilled_unstroked
            @builder.raw("/>")
          else
            emit_stroke_draw
            @builder.raw("fill=\"none\" />")
          end
          @builder.newline
        end
        # Mirror libemf2svg's point*_draw: the final emitted point becomes
        # the new current position for subsequent drawing records.
        return unless last_pt

        @current_x = int(last_pt.x)
        @current_y = int(last_pt.y)
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
            d << "M #{fmt(cal_x(int(pt.x)))} #{fmt(cal_y(int(pt.y)))} "
          when pt_lineto
            d << "L #{fmt(cal_x(int(pt.x)))} #{fmt(cal_y(int(pt.y)))} "
          when pt_bezierto
            bezier_buf << pt
            if bezier_buf.size == 3
              d << "C #{fmt(cal_x(int(bezier_buf[0].x)))} #{fmt(cal_y(int(bezier_buf[0].y)))} "
              d << "#{fmt(cal_x(int(bezier_buf[1].x)))} #{fmt(cal_y(int(bezier_buf[1].y)))} "
              d << "#{fmt(cal_x(int(bezier_buf[2].x)))} #{fmt(cal_y(int(bezier_buf[2].y)))} "
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
        # Pass cb_bmi as bits_offset so the decoder reads pixels from the
        # actual start of the bitmap bits, not from header+palette (which
        # would misread if the BMI has trailing padding).
        result = DibDecoder.decode(dib_bytes, bits_offset: cb_bmi)
        return unless result

        href = build_image_href(result)
        # libemf2svg's U_EMRSTRETCHDIBITS_draw uses point_cal for both size
        # (cDest) and position (Dest). Match that exactly so window/viewport
        # origins are applied to the dimensions too.
        geom = "width=\"#{fmt(cal_x(width))}\" height=\"#{fmt(cal_y(height))}\" " \
               "x=\"#{fmt(cal_x(x))}\" y=\"#{fmt(cal_y(y))}\""
        @builder.raw("<image ")
        @builder.raw(geom)
        @builder.raw(" ")
        @builder.raw(clip_path_attr_string)
        @builder.raw("xlink:href=\"")
        @builder.raw(href)
        @builder.raw("\" ")
        @builder.raw("/>")
        @builder.newline
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
          # libemf2svg uses "image/jpg" (not the standard "image/jpeg").
          # Also apply fmem modulo-3 padding so the base64 has 'AA' trailing
          # chars instead of '=' (the C base64_encode allocates length+3
          # for nulls and the partial-triple bytes default to 0).
          jpeg = result.pixels.to_s
          rem = jpeg.bytesize % 3
          jpeg << ("\x00" * ((3 - rem) % 3)) if rem != 0
          "data:image/jpg;base64,#{[jpeg].pack('m0')}"
        when :png
          "data:image/png;base64,#{[result.pixels].pack('m0')}"
        else
          png_bytes = PngEncoder.encode(result.width, result.height, result.pixels)
          "data:image/png;base64,#{[png_bytes].pack('m0')}"
        end
      end

      # BitBlt with no source bitmap is used as a "fill rectangle with
      # current brush" operation. libemf2svg's U_EMRBITBLT_draw emits
      # different SVG depending on fill_mode:
      #   BS_SOLID:       <path style="fill:#rrggbb" d="M x,y L x+w,y L x+w,y+h L x,y+h Z" />
      #   BS_MONOPATTERN: <path style="fill:url(#img-N-ref);" d="..." />
      # For other modes, emits nothing. Also emits nothing if dwRop == NOOP.
      # We replicate only the BS_SOLID path here.
      def emit_bitblt_solid_fill(wire)
        rop = wire.dw_rop.to_i
        return if rop == 0x00AA0029 # U_NOOP

        brush = @dc.brush
        return unless brush.style == Brush::SOLID

        style = format("fill:#%02x%02x%02x", brush.color.red, brush.color.green, brush.color.blue)
        size_x = scale_dim_x(wire.cx_dest.to_i)
        size_y = scale_dim_y(wire.cy_dest.to_i)
        pos_x = cal_x(wire.x_dest)
        pos_y = cal_y(wire.y_dest)
        @builder.raw("<path style=\"#{style}\"")
        @builder.raw(" d=\"M #{fmt(pos_x)},#{fmt(pos_y)} ")
        @builder.raw("L #{fmt(pos_x + size_x)},#{fmt(pos_y)} ")
        @builder.raw("L #{fmt(pos_x + size_x)},#{fmt(pos_y + size_y)} ")
        @builder.raw("L #{fmt(pos_x)},#{fmt(pos_y + size_y)} ")
        @builder.raw("Z\" />")
      end

      def emit_path_polygon(points, closed:)
        return if points.empty?

        if @in_path
          # Inside BeginPath..EndPath: append `M X,Y L X,Y ...` directly to
          # the open d-string (no element wrapping, no Z — Z is added by
          # CloseFigure or by the path closer at EndPath/FillPath/etc.).
          @builder.raw("M ")
          @builder.raw(point_str(points.first))
          points[1..].each do |p|
            @builder.raw("L ")
            @builder.raw(point_str(p))
          end
          # Mirror libemf2svg's point*_draw which updates cur_x,cur_y on
          # every emitted point — the LAST point becomes the new current
          # position, used by subsequent PolyBezier/LineTo/etc.
          @current_x = int(points.last.x)
          @current_y = int(points.last.y)
          return
        end

        d = +"M "
        d << point_str(points.first)
        points[1..].each do |p|
          d << "L "
          d << point_str(p)
        end
        emit_path_element(d, closed: closed)
        @current_x = int(points.last.x)
        @current_y = int(points.last.y)
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
      def point_str(point)
        fmt_xy(cal_x(int(point.x)), cal_y(int(point.y)))
      end

      # libemf2svg prints colors as `#RRGGBB` always (drops alpha/reserved).
      # The text depends only on the three channels, so each distinct colour
      # is formatted once and the frozen string is shared.
      def rgb_hex(color)
        red = color.red
        green = color.green
        blue = color.blue
        return format("#%02X%02X%02X", red, green, blue) unless (red | green | blue).nobits?(-256)

        @rgb_hex_cache ||= {}
        @rgb_hex_cache[(red << 16) | (green << 8) | blue] ||=
          format("#%02X%02X%02X", red, green, blue).freeze
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
        # C's fill_draw computes fill_rule from a switch that overlaps brush
        # style constants with poly-fill modes (BS_NULL==TA_ALTERNATE=1 →
        # "evenodd", BS_HATCHED==TA_WINDING=2 → "nonzero", else " "). The
        # fill_rule is ONLY emitted in the BS_SOLID branch of the second
        # switch — other branches ignore it. We replicate that exactly.
        fill_rule = case brush.style
                    when Brush::NULL then 'fill-rule:"evenodd" '
                    when Brush::HATCHED then 'fill-rule:"nonzero" '
                    else " "
                    end
        case brush.style
        when Brush::SOLID
          @builder.raw(fill_rule)
          @builder.raw(fill_color_attr(brush))
        when Brush::NULL
          @builder.raw("fill=\"none\" ")
        when Brush::MONOPATTERN
          @builder.raw("fill=\"#img-#{brush.image_id}-ref\" ")
        else
          # BS_HATCHED, BS_PATTERN, etc. — C's default branch emits ONLY the
          # fill attr (fill_rule is computed but discarded).
          @builder.raw(fill_color_attr(brush))
        end
        @last_fill_set = true
      end

      def fill_color_attr(brush)
        "fill=\"#{rgb_hex(brush.color)}\" "
      end

      # Mirror libemf2svg's stroke_draw. Emits stroke attrs depending on pen
      # type (NULL/COSMETIC/GEOMETRIC) and dash style. Does NOT add a leading
      # space — the caller is responsible for spacing.
      def emit_stroke_draw
        pen = @dc.pen
        @last_stroke_set = false
        style = pen.style

        if (style & 0xFF) == Pen::NULL
          if @dc.brush.style == Brush::NULL
            @builder.raw("stroke=\"none\" stroke-width=\"0.0\" ")
          else
            @builder.raw("stroke-width=\"1px\" stroke=\"#{rgb_hex(@dc.brush.color)}\" ")
          end
          @last_stroke_set = true
          return
        end

        # Color then width (C order: color_stroke then width_stroke).
        # COSMETIC pen uses hardcoded width=1; GEOMETRIC uses pen.width.
        pen_type = style & 0x000F0000
        width_for_emit = pen_type == 0x00010000 ? pen.width : 1
        @builder.raw("stroke=\"#{rgb_hex(pen.color)}\" ")
        emit_width_stroke(width_for_emit)
        @last_stroke_set = true

        # Dash style
        unit_stroke = (pen.width || 1) * @scaling
        dash_len = unit_stroke * 5
        dot_len = unit_stroke
        case style & 0xFF
        when Pen::DASH
          @builder.raw("stroke-dasharray=\"#{fmt(dash_len)},#{fmt(dash_len)}\" ")
        when Pen::DOT
          @builder.raw("stroke-dasharray=\"#{fmt(dot_len)},#{fmt(dot_len)}\" ")
        when Pen::DASHDOT
          @builder.raw("stroke-dasharray=\"#{fmt(dash_len)},#{fmt(dash_len)},#{fmt(dot_len)},#{fmt(dash_len)}\" ")
        when Pen::DASHDOTDOT
          @builder.raw("stroke-dasharray=\"#{fmt(dash_len)},#{fmt(dash_len)},#{fmt(dot_len)}," \
                       "#{fmt(dot_len)},#{fmt(dot_len)},#{fmt(dash_len)}\" ")
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
          @builder.raw(" stroke-miterlimit=\"#{fmt(@scaling * @dc.miter_limit)}\" ") if @dc.miter_limit
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
          @builder.raw("stroke-width=\"#{fmt(tmp_w)}\" ")
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

        { "fill" => rgb_hex(brush.color) }.merge(clip_attrs)
      end

      def emit_hatch_pattern(id, hatch_style, fg_color, bk_color, bk_mode)
        lines = HATCH_PATTERNS[hatch_style] || HATCH_PATTERNS[0]
        bk = bk_mode == 2 ? rgb_hex(bk_color) : "none"
        fg = rgb_hex(fg_color)
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
                   "stroke" => rgb_hex(@dc.brush.color) }.merge(clip_attrs)

        end

        w = [pen.width, 1].max
        attrs = { "stroke" => rgb_hex(pen.color), "stroke-width" => w }

        # Line style (bits 0-7)
        dash_len = w * 5
        dot_len = w
        case style & 0xFF
        when Pen::DASH
          attrs["stroke-dasharray"] = "#{fmt(dash_len)},#{fmt(dash_len)}"
        when Pen::DOT
          attrs["stroke-dasharray"] = "#{fmt(dot_len)},#{fmt(dot_len)}"
        when Pen::DASHDOT
          attrs["stroke-dasharray"] = "#{fmt(dash_len)},#{fmt(dash_len)},#{fmt(dot_len)},#{fmt(dash_len)}"
        when Pen::DASHDOTDOT
          attrs["stroke-dasharray"] =
            "#{fmt(dash_len)},#{fmt(dash_len)},#{fmt(dot_len)},#{fmt(dot_len)},#{fmt(dot_len)},#{fmt(dash_len)}"
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
          attrs["stroke-miterlimit"] = fmt(@dc.miter_limit) if @dc.miter_limit
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
        @dc.window_ext_set? && @dc.viewport_ext_set?
      end

      def maybe_flip_y(y)
        cal_y(y)
      end

      def emit_transform_group(matrix)
        # Mirror libemf2svg's transform_draw: close previous transform group
        # before opening new one, emit `<g transform="matrix(...)">\n`,
        # with eDx/eDy passed through scaleX/scaleY (sign-preserving).
        # Skip emission while inside a BeginPath..EndPath block — transforms
        # are deferred to BeginPath/EndPath in C's two-pass analysis.
        return if @in_path

        if @open_groups.positive?
          @builder.rawln("</g>")
          @open_groups -= 1
        end
        dx_scaled = matrix.dx * sf_x * @scaling
        dy_scaled = matrix.dy * sf_y * @scaling
        @builder.rawln("<g transform=\"matrix(#{fmt(matrix.m11)} #{fmt(matrix.m12)} #{fmt(matrix.m21)} " \
                       "#{fmt(matrix.m22)} #{fmt(dx_scaled)} #{fmt(dy_scaled)})\">")
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
