# frozen_string_literal: true

require "emf"

module Emfsvg
  module Translation
    module Handlers
      # Mixed into element handlers. Provides the per-element GDI object
      # lifecycle: Create+Select before the block, Delete after.
      #
      # Strategy (v1): always emit CreatePen + CreateBrushIndirect +
      # SelectObject + (draw) + DeleteObject, even when the SVG value
      # is "none". This produces a literal 1:1 mapping of the SVG tree
      # to EMF records and is what the round-trip test exercises.
      #
      # If the element has a rectangular clip-path, the entire draw is
      # wrapped in SaveDC + IntersectClipRect + RestoreDC. Adjacent built-in
      # drawings that install all state they read can share that single scope.
      module SharedGdi
        include Emf::Emr::Binary::TypeCodes

        def with_gdi_state(element, context)
          clip_bounds = clip_bounds_for(element, context)
          wrap_with_clip = !clip_bounds.nil?

          signature = clip_scope_signature(element, context, clip_bounds)
          reuse_clip = context.reuse_clip_scope?(signature)
          emit_save_dc(context) if wrap_with_clip && !reuse_clip
          if element.stroke && !element.stroke.paint.null?
            context.emit(Emf::Emr::Binary::Records::SetMiterLimit,
                         i_type: SETMITERLIMIT,
                         miter_limit: serialized_miter_limit(element))
          end
          pen_handle = emit_create_pen(context, element.stroke) if element.stroke
          brush = element.stroke&.fallback_brush || element.fill
          brush_handle = emit_create_brush(context, brush) if brush
          if wrap_with_clip && !reuse_clip
            context.emit(Emf::Emr::Binary::Records::IntersectClipRect,
                         i_type: INTERSECTCLIPRECT,
                         rcl_clip: context.rect_attrs(*clip_bounds))
          end
          yield
          emit_delete(context, pen_handle) if pen_handle
          emit_delete(context, brush_handle) if brush_handle
          return unless wrap_with_clip

          restore = emit_restore_dc(context)
          context.remember_clip_scope(signature, restore)
        end

        def serialized_miter_limit(element)
          limit = element.stroke.miter_limit
          return limit unless element.is_a?(Svg::Elements::Path) && element.line_record_kind == :polyline_to
          return limit unless limit.between?(1, 0x7FFFFF) && limit == limit.to_i

          # Legacy PolylineTo provenance uses libuemf's integer wire contract.
          # The dependency exposes a float field; subnormal bits preserve the
          # integer payload, which our reader also recognizes. Other limits
          # retain floats rather than truncating or exceeding that reader range.
          [limit.to_i].pack("V").unpack1("e")
        end

        def clip_scope_signature(element, context, clip_bounds)
          return unless clip_bounds && complete_draw_state?(element)

          [:complete_draw, context.rect_attrs(*clip_bounds), context.canonical_empty_clip_scope?(element)]
        end

        def complete_draw_state?(element)
          # Exact built-ins opt in: custom handlers may depend on inherited
          # state. Shapes install pen/brush/miter and absolute geometry;
          # untransformed text installs font/color/alignment and its position.
          return !element.transformed? if instance_of?(TextHandler)

          [PathHandler, RectHandler, EllipseHandler, LineHandler,
           PolylineHandler, PolygonHandler].include?(self.class) && element.stroke && element.fill
        end

        def clip_bounds_for(element, context)
          return nil if context.clip_path_registry.nil?

          attr = element.clip_path
          return nil if attr.nil?

          clip = context.clip_path_registry.lookup(attr)
          return nil unless clip
          return nil if context.carried_clip?(clip) || context.selected_clip?(clip) || context.interval_clip?(clip)

          clip.clip_bounds
        end

        def emit_save_dc(context)
          context.emit(Emf::Emr::Binary::Records::SaveDc, i_type: SAVEDC)
        end

        def emit_restore_dc(context)
          context.emit(Emf::Emr::Binary::Records::RestoreDc,
                       i_type: RESTOREDC, saved_dc: -1)
        end

        def emit_create_pen(context, stroke)
          handle = context.allocate_handle
          width = if stroke.canonical_cosmetic_dash
                    # Cosmetic dash lengths use stored width without coordinate mapping.
                    { x: stroke.canonical_cosmetic_dash[0], y: 0 }
                  elsif stroke.cosmetic_pixel_width?
                    { x: 1, y: 0 }
                  else
                    context.point_attrs(stroke.width, 0)
                  end
          context.emit(Emf::Emr::Binary::Records::CreatePen,
                       i_type: CREATEPEN,
                       ih_pen: handle,
                       pen_style: stroke.pen_style,
                       width: width,
                       color: stroke.paint.color.wire_attrs)
          context.emit(Emf::Emr::Binary::Records::SelectObject,
                       i_type: SELECTOBJECT,
                       ih_object: handle)
          handle
        end

        def emit_create_brush(context, paint)
          handle = context.allocate_handle
          context.emit(Emf::Emr::Binary::Records::CreateBrushIndirect,
                       i_type: CREATEBRUSHINDIRECT,
                       ih_brush: handle,
                       brush_style: paint.style,
                       color: paint.color.wire_attrs,
                       brush_hatch: 0)
          context.emit(Emf::Emr::Binary::Records::SelectObject,
                       i_type: SELECTOBJECT,
                       ih_object: handle)
          handle
        end

        def emit_delete(context, handle)
          context.emit(Emf::Emr::Binary::Records::DeleteObject,
                       i_type: DELETEOBJECT,
                       ih_object: handle)
        end
      end
    end
  end
end
