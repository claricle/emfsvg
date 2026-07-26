# frozen_string_literal: true

module Emfsvg
  module Svg
    # Parsed SVG `stroke=` and `fill=` attribute values, mapped to a
    # value object the translation layer can consume.
    #
    # `Paint` is a thin struct: it carries a `Color` (which may be the
    # NULL sentinel for "none") and the original brush/pen style bits.
    class Paint
      SOLID = 0
      NULL = 1

      def initialize(color:, style: SOLID)
        @style = style
        @color = color
      end

      attr_reader :style, :color

      def null?
        style == NULL || color.null?
      end

      def self.from_fill(value)
        color = Color.parse(value)
        new(style: color.null? ? NULL : SOLID, color: color)
      end

      def self.from_stroke(value)
        color = Color.parse(value)
        new(style: color.null? ? NULL : SOLID, color: color)
      end
    end
  end
end
