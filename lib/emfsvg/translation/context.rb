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
      end

      # Allocate the next 1-indexed GDI object handle. Always increments
      # — no reuse in v1 (see TODO.roadmap/09-coalescing-optimization.adoc).
      def allocate_handle
        handle = @next_handle
        @next_handle += 1
        handle
      end

      # Takes the record's attributes as one Hash (callers still write
      # them as keywords) and passes that same Hash on, so forwarding adds
      # no Hash per hop.
      def emit(wire_class, attrs)
        @emitter.emit(wire_class, attrs)
      end

      def records
        @emitter.records
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
