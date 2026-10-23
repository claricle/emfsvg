# frozen_string_literal: true

module Emfsvg
  module Svg
    # Root of a parsed SVG document. Carries the viewport geometry from
    # the outer <svg width height viewBox> element plus the (lazily
    # parsed) child element tree.
    #
    # emfsvg's EMF→SVG renderer always wraps content in
    # `<g transform="translate(-bounds.left, -bounds.top)">`. For
    # byte-clean round-trip, the SVG→EMF side detects this "header
    # translate group" and uses it to recover the EMF bounds origin
    # instead of emitting a redundant SetWorldTransform.
    class Document
      def initialize(width:, height:, root_element:, view_box: nil)
        @width = width
        @height = height
        @view_box = view_box
        @root_element = root_element
      end

      attr_reader :width, :height, :view_box, :root_element

      # The Group that represents the emfsvg-emitted header translate,
      # or nil if no such group is present. This group's contents are
      # dispatched directly (without the wrapping translate); the
      # translate feeds the EMF header bounds instead.
      def header_translate_group
        candidate = first_child
        return nil unless candidate.is_a?(Elements::Group)

        matrix = candidate.transform_matrix
        return nil unless matrix
        return nil unless translate_only?(matrix)

        candidate
      end

      # True when the header translate group carries the legacy broken-Y
      # marker (see Elements::Group::LEGACY_BROKEN_Y_TRANSFORM).
      def legacy_broken_y_header?
        group = header_translate_group
        !group.nil? && group.legacy_broken_y?
      end

      # A matrix equivalent to a pure translate: identity 2×2 portion
      # (modulo floating-point rounding).
      IDENTITY_TOLERANCE = 1e-9

      def translate_only?(matrix)
        (matrix.m11 - 1.0).abs < IDENTITY_TOLERANCE &&
          (matrix.m22 - 1.0).abs < IDENTITY_TOLERANCE &&
          matrix.m12.abs < IDENTITY_TOLERANCE &&
          matrix.m21.abs < IDENTITY_TOLERANCE
      end

      # [min_x, min_y, w, h] for the EMF bounds.
      def bounds
        return view_box if view_box

        group = header_translate_group
        if group
          matrix = group.transform_matrix
          return [-matrix.dx, -matrix.dy, width, height]
        end

        [0, 0, width, height]
      end

      private

      def first_child
        root_element.is_a?(Element) ? root_element.children.first : nil
      end
    end
  end
end
