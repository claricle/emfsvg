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
      PATTERN = 3

      def initialize(color:, style: SOLID, reference: nil)
        @style = style
        @color = color
        @reference = reference
      end

      attr_reader :style, :color, :reference

      def null?
        style == NULL || color.null?
      end

      def self.from_fill(value)
        if (match = /\A(?:#(img-[1-9]\d*-ref)|url\(#(img-[1-9]\d*-ref)\))\z/.match(value.to_s))
          return new(style: PATTERN, color: Color.parse("black"), reference: match[1] || match[2])
        end

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
