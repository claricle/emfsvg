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
                  :handler_registry, :clip_path_registry, :scaler, :pattern_handles

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
        @pattern_handles = {}
        @unused_clip_safe = true
        @local_origin = [0, 0]
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
        if @drawing_hint && DrawingHint::DRAW_TYPES.include?(attrs[:i_type])
          kind, values = @drawing_hint
          @drawing_hint = nil
          record = @emitter.build(wire_class, attrs)
          data = DrawingHint.encode(record, kind, values)
          @emitter.emit(Emf::Emr::Binary::Records::Comment,
                        i_type: Emf::Emr::Binary::TypeCodes::COMMENT,
                        cb_data: data.bytesize, data: data.ljust((data.bytesize + 3) & ~3, "\x00"))
        end
        @emitter.emit(wire_class, attrs)
      end

      def with_drawing_hint(element)
        @drawing_hint = DrawingHint.for_element(element)
        yield
      ensure
        @drawing_hint = nil
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

      def preserve_unused_selected_clip(clip)
        return unless @unused_clip_safe && @handler_registry.equal?(EmfRenderer::DEFAULT_REGISTRY)
        return unless @clip_path_registry&.unused_selected_clip?(clip)

        @emitter.emit(Emf::Emr::Binary::Records::SelectClipPath,
                      i_type: Emf::Emr::Binary::TypeCodes::SELECTCLIPPATH, region_mode: 5)
        @emitter.emit(Emf::Emr::Binary::Records::ExtSelectClipRgn,
                      i_type: Emf::Emr::Binary::TypeCodes::EXTSELECTCLIPRGN,
                      cb_rgn_data: 0, dw_mode: 5)
        true
      end

      # Registry proves an exclusive drawing tail in a saved identity group.
      # Its RestoreDC returns to the known-empty clip, so these selections do
      # not disable preservation of later unused definitions.
      def begin_selected_clip(group)
        clip = @clip_path_registry&.selected_clip(group)
        @selected_clip = clip if clip && @unused_clip_safe
      end

      def preserve_selected_clip(clip)
        return unless clip && (@selected_clip.equal?(clip) || (@interval_clip.equal?(clip) && clip.selected_path_data))

        @emitter.emit(Emf::Emr::Binary::Records::SelectClipPath,
                      i_type: Emf::Emr::Binary::TypeCodes::SELECTCLIPPATH, region_mode: 5)
        @active_selected_clip = clip
        true
      end

      def selected_clip?(clip)
        clip && @active_selected_clip.equal?(clip)
      end

      def finish_selected_clip(group)
        clip = @clip_path_registry&.selected_clip(group)
        return unless clip
        return unless clip.equal?(@selected_clip)

        @selected_clip = @active_selected_clip = nil
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

      # Complete draws save the previously empty clip and restore it. Only the
      # renderer's canonical rectangle provenance permits preserving subsequent
      # unused definitions; ordinary clip mutations remain conservative.
      def canonical_empty_clip_scope?(element)
        return false unless @unused_clip_safe && !@carried_clip && !@active_selected_clip

        clip = @clip_path_registry&.lookup(element.clip_path)
        !!clip&.unused_rectangle_bounds
      end

      def remember_clip_scope(signature, restore)
        @unused_clip_safe = true if signature && signature[2]
        @clip_scope_tail = [signature, records.size - 1, restore] if signature
      end

      # Move only an adjacent identical text run's terminal deletion. Any
      # intervening record, including a group boundary, ends the font lifetime.
      def reuse_text_state(signature)
        previous = @text_state_tail
        @text_state_tail = nil
        return unless signature && previous
        return unless previous[0] == signature && previous[1] == records.size - 1
        return unless records.last.equal?(previous[2])

        records.pop
        previous[3]
      end

      def remember_text_state(signature, handle, deletion)
        @text_state_tail = [signature, records.size - 1, deletion, handle] if signature
      end

      def interval_clip?(clip)
        clip && @interval_clip.equal?(clip)
      end

      def with_clip_interval(element)
        empty_group = empty_interval_group?(element)
        clip = @clip_path_registry&.interval_start(element) if @handler_registry.equal?(EmfRenderer::DEFAULT_REGISTRY)
        if clip && (@unused_clip_safe || @interval_clip) && !@carried_clip && !@active_selected_clip
          @clip_scope_tail = nil
          (@interval_stack ||= []) << [@interval_clip, @unused_clip_safe]
          @interval_clip = clip
          emit(Emf::Emr::Binary::Records::SaveDc, i_type: Emf::Emr::Binary::TypeCodes::SAVEDC)
          if clip.unused_rectangle_bounds
            emit(Emf::Emr::Binary::Records::IntersectClipRect,
                 i_type: Emf::Emr::Binary::TypeCodes::INTERSECTCLIPRECT,
                 rcl_clip: rect_attrs(*clip.unused_rectangle_bounds))
          end
        end
        yield
        finish_clip_interval if @interval_clip && @clip_path_registry.interval_end(element).equal?(@interval_clip)
        # A nested interval leaves snapshots in reference readers. The group's
        # native RestoreDC returns to its proven empty entry clip.
        reset_empty_clip if empty_group && empty_clip?
      end

      def finish_clip_interval
        emit(Emf::Emr::Binary::Records::RestoreDc,
             i_type: Emf::Emr::Binary::TypeCodes::RESTOREDC, saved_dc: -1)
        # Native RestoreDC pops the interval; the reference renderer retains
        # snapshots. Explicitly resetting its clip agrees with native empty state.
        @active_selected_clip = nil if @active_selected_clip.equal?(@interval_clip)
        @interval_clip, @unused_clip_safe = @interval_stack.pop
        unless @interval_clip
          reset_empty_clip
          @unused_clip_safe = true
        end
        @clip_scope_tail = nil
      end

      def empty_interval_group?(element)
        @handler_registry.equal?(EmfRenderer::DEFAULT_REGISTRY) &&
          @clip_path_registry&.interval_group?(element) && empty_clip?
      end

      def empty_clip?
        @unused_clip_safe && !@interval_clip && !@carried_clip && !@active_selected_clip
      end

      def reset_empty_clip
        emit(Emf::Emr::Binary::Records::ExtSelectClipRgn,
             i_type: Emf::Emr::Binary::TypeCodes::EXTSELECTCLIPRGN, cb_rgn_data: 0, dw_mode: 5)
      end

      # Dispatch an element through the registry. Container handlers
      # (e.g. GroupHandler) call this to recurse into their children.
      def dispatch(element)
        handler = @handler_registry.handler_for(element)
        with_clip_interval(element) { handler&.call(element, self) }
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

      # Viewport origins use device units, while the line's coordinates retain
      # the fixed logical scale. Explicit reset also supports readers whose
      # mapping origins are not part of their saved device context.
      def with_local_origin(origin)
        return yield unless origin

        previous = @local_origin
        emit(Emf::Emr::Binary::Records::SaveDc, i_type: Emf::Emr::Binary::TypeCodes::SAVEDC)
        emit_viewport_origin(origin)
        @local_origin = origin
        begin
          yield
        ensure
          @local_origin = previous
          emit_viewport_origin(previous)
          emit(Emf::Emr::Binary::Records::RestoreDc,
               i_type: Emf::Emr::Binary::TypeCodes::RESTOREDC, saved_dc: -1)
        end
      end

      def emit_viewport_origin(origin)
        emit(Emf::Emr::Binary::Records::SetViewportOrgEx,
             i_type: Emf::Emr::Binary::TypeCodes::SETVIEWPORTORGEX,
             origin: { x: origin[0], y: origin[1] })
      end
      private :emit_viewport_origin

      # Attribute-hash forms of the helpers above. A record field accepts
      # a Hash and builds its nested value in place, which avoids
      # constructing a throwaway BinData object per coordinate that the
      # record would only copy. Handlers use these when emitting.
      def point_attrs(x, y)
        { x: scale_int(x - @local_origin[0]), y: scale_int(y - @local_origin[1]) }
      end

      def rect_attrs(left, top, right, bottom)
        {
          left: scale_int(left - @local_origin[0]), top: scale_int(top - @local_origin[1]),
          right: scale_int(right - @local_origin[0]), bottom: scale_int(bottom - @local_origin[1])
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
