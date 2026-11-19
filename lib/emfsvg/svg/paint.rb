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

      # `fill="url(#id)"` — a reference to a paint server (<pattern>,
      # <linearGradient>, <radialGradient>) defined in the document.
      URL_REFERENCE_RE = /\Aurl\(\s*["']?#([^)"'\s]+)["']?\s*\)\z/
      private_constant :URL_REFERENCE_RE

      # `fill="#id"` — bare fragment reference spelling. Kept as a
      # reference only when the fragment is NOT a hex color (those are
      # colors and go to Color.parse).
      BARE_REFERENCE_RE = /\A#([^\s)"']+)\z/
      HEX_COLOR_RE = /\A#[0-9a-fA-F]{3}\z|\A#[0-9a-fA-F]{6}\z/
      private_constant :BARE_REFERENCE_RE, :HEX_COLOR_RE

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
        if (match = URL_REFERENCE_RE.match(value.to_s))
          return pattern_reference(match[1])
        end

        if (match = BARE_REFERENCE_RE.match(value.to_s)) && !HEX_COLOR_RE.match?(value.to_s)
          return pattern_reference(match[1])
        end

        color = Color.parse(value)
        new(style: color.null? ? NULL : SOLID, color: color)
      end

      def self.from_stroke(value)
        color = Color.parse(value)
        new(style: color.null? ? NULL : SOLID, color: color)
      end

      # A referenced paint server carries black as its wire color. When
      # the translation layer resolves the reference to a bitmap pattern
      # brush, the brush's DIB decides the appearance; when it cannot
      # resolve it (gradient, unknown id), black is the solid fallback
      # that keeps the draw visible instead of failing the translation.
      def self.pattern_reference(id)
        new(style: PATTERN, color: Color.parse("black"), reference: id)
      end
      private_class_method :pattern_reference
    end
  end
end
