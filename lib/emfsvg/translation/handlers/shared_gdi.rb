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
      # paths with identical complete styles can share that single scope.
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
                         miter_limit: element.stroke.miter_limit)
          end
          pen_handle = emit_create_pen(context, element.stroke) if element.stroke
          brush_handle = emit_create_brush(context, element.fill) if element.fill
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

        def clip_scope_signature(element, context, clip_bounds)
          # Only this built-in handler installs complete geometry without
          # changing any other persistent GDI state. Custom handlers opt out.
          return unless instance_of?(PathHandler) && clip_bounds && element.stroke && element.fill

          stroke = element.stroke
          fill = element.fill
          [self.class, context.rect_attrs(*clip_bounds),
           stroke.pen_style, context.point_attrs(stroke.width, 0), stroke.paint.color.to_emf_wire.to_wire,
           stroke.miter_limit,
           fill.style, fill.color.to_emf_wire.to_wire, 0]
        end

        def clip_bounds_for(element, context)
          return nil if context.clip_path_registry.nil?

          attr = element.clip_path
          return nil if attr.nil?

          clip = context.clip_path_registry.lookup(attr)
          return nil unless clip

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
          context.emit(Emf::Emr::Binary::Records::CreatePen,
                       i_type: CREATEPEN,
                       ih_pen: handle,
                       pen_style: stroke.pen_style,
                       width: context.point_attrs(stroke.width, 0),
                       color: stroke.paint.color.to_emf_wire.to_wire)
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
                       color: paint.color.to_emf_wire.to_wire,
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
