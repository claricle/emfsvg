# frozen_string_literal: true

require "emf"

module Emfsvg
  module Translation
    # Mutable translation state carried through the element tree walk.
    #
    # Holds the GDI device context (pen/brush/font/transform), the
    # 1-indexed object table, the SaveDC/RestoreDC stack, the
    # coordinate scaler, and the output record list. All handlers
    # receive a Context instance and operate on it functionally.
    #
    # Context also carries a reference to the HandlerRegistry so that
    # GroupHandler (and other container handlers) can recurse into
    # their children uniformly.
    class Context
      attr_reader :device_context, :object_table, :transform_stack, :emitter,
                  :handler_registry, :clip_path_registry, :scaler

      def initialize(handler_registry: EmfRenderer::DEFAULT_REGISTRY,
                     clip_path_registry: nil,
                     scaler: Scaler::Identity.new)
        @device_context = DeviceContext.new
        @object_table = ObjectTable.new
        @transform_stack = TransformStack.new
        @emitter = RecordEmitter.new
        @handler_registry = handler_registry
        @clip_path_registry = clip_path_registry
        @scaler = scaler
        @next_handle = 1
        @unused_clip_safe = true
      end

      # Allocate the next 1-indexed GDI object handle. Always increments
      # — no reuse in v1 (see TODO.roadmap/09-coalescing-optimization.adoc).
      def allocate_handle
        handle = @next_handle
        @next_handle += 1
        handle
      end

      # Includes the reserved zero slot required by the EMF header.
      def handle_table_size
        @next_handle
      end

      CLIP_MUTATIONS = %i[INTERSECTCLIPRECT EXCLUDECLIPRECT EXTSELECTCLIPRGN
                          OFFSETCLIPRGN SELECTCLIPPATH SETMETARGN].map do |name|
        Emf::Emr::Binary::TypeCodes.const_get(name)
      end.freeze

      def emit(wire_class, attrs)
        # Once an ordinary clip operation occurs, conservatively stop emitting
        # unused resources. RestoreDC need not be modeled to prove a reset safe.
        @unused_clip_safe = false if CLIP_MUTATIONS.include?(attrs[:i_type])
        @emitter.emit(wire_class, attrs)
      end

      def emit_unused_clip_rectangle(bounds)
        return unless @unused_clip_safe

        # These paired operations leave the known-empty clip unchanged and
        # introduce no SaveDC snapshot into either native or reference stacks.
        @emitter.emit(Emf::Emr::Binary::Records::IntersectClipRect,
                      i_type: Emf::Emr::Binary::TypeCodes::INTERSECTCLIPRECT,
                      rcl_clip: rect_attrs(*bounds))
        @emitter.emit(Emf::Emr::Binary::Records::ExtSelectClipRgn,
                      i_type: Emf::Emr::Binary::TypeCodes::EXTSELECTCLIPRGN,
                      cb_rgn_data: 0, dw_mode: 5)
      end

      def carried_clip?(clip)
        clip && @carried_clip.equal?(clip)
      end

      def carry_clip_from(group)
        clip = @clip_path_registry&.exported_clip(group)
        return unless clip && @unused_clip_safe

        @carried_clip = clip
        @emitter.emit(Emf::Emr::Binary::Records::IntersectClipRect,
                      i_type: Emf::Emr::Binary::TypeCodes::INTERSECTCLIPRECT,
                      rcl_clip: rect_attrs(*clip.unused_rectangle_bounds))
      end

      def finish_carried_clip(group)
        clip = @clip_path_registry&.imported_clip(group)
        return unless carried_clip?(clip)

        @emitter.emit(Emf::Emr::Binary::Records::ExtSelectClipRgn,
                      i_type: Emf::Emr::Binary::TypeCodes::EXTSELECTCLIPRGN,
                      cb_rgn_data: 0, dw_mode: 5)
        @carried_clip = nil
      end

      def records
        @emitter.records
      end

      # Reuse only the exact tail restore from a compatible complete clipped draw.
      # Keeping one outer SaveDC/RestoreDC pair also preserves native EMF
      # popping semantics; nested saves cannot be coalesced this way.
      def reuse_clip_scope?(signature)
        previous = @clip_scope_tail
        @clip_scope_tail = nil
        return false unless signature && previous
        return false unless previous[0] == signature && previous[1] == records.size - 1
        return false unless records.last.equal?(previous[2])

        records.pop
        true
      end

      def remember_clip_scope(signature, restore)
        @clip_scope_tail = [signature, records.size - 1, restore] if signature
      end

      # Dispatch an element through the registry. Container handlers
      # (e.g. GroupHandler) call this to recurse into their children.
      def dispatch(element)
        handler = @handler_registry.handler_for(element)
        handler&.call(element, self)
      end

      # ---- Coordinate-scaled wire helpers (DRY: handlers route all
      # coords through these so the scaler affects everything) ----

      def point_l(x, y)
        Emf::Binary::Types::PointL.new(**point_attrs(x, y))
      end

      def rect_l(left, top, right, bottom)
        Emf::Binary::Types::RectL.new(**rect_attrs(left, top, right, bottom))
      end

      def size_l(cx, cy)
        Emf::Binary::Types::SizeL.new(**size_attrs(cx, cy))
      end

      # Attribute-hash forms of the helpers above. A record field accepts
      # a Hash and builds its nested value in place, which avoids
      # constructing a throwaway BinData object per coordinate that the
      # record would only copy. Handlers use these when emitting.
      def point_attrs(x, y)
        { x: scale_int(x), y: scale_int(y) }
      end

      def rect_attrs(left, top, right, bottom)
        {
          left: scale_int(left), top: scale_int(top),
          right: scale_int(right), bottom: scale_int(bottom)
        }
      end

      def size_attrs(cx, cy)
        { cx: scale_int(cx), cy: scale_int(cy) }
      end

      # Convert a Matrix to its wire form, scaling the translation
      # (dx/dy) by the scaler's factor. The 2x2 rotation/scale
      # coefficients are NOT scaled — they're dimensionless ratios
      # and survive any isometric map-mode change intact.
      def xform_wire_from(matrix)
        factor = @scaler.factor
        return matrix.to_wire if factor == 1

        scaled = Emf::Model::Geometry::Matrix.new(
          m11: matrix.m11, m12: matrix.m12,
          m21: matrix.m21, m22: matrix.m22,
          dx: matrix.dx * factor,
          dy: matrix.dy * factor
        )
        scaled.to_wire
      end

      private

      def scale_int(value)
        @scaler.to_int(value)
      end
    end
  end
end
