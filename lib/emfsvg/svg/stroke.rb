# frozen_string_literal: true

module Emfsvg
  module Svg
    # Parsed SVG stroke style: color, width, dash pattern, line cap,
    # line join, and miter limit.
    #
    # Pen style bits (per MS-WMF 2.1.1.8 / emr_visitor.rb mirror):
    #
    #   PS_SOLID=0, PS_DASH=1, PS_DOT=2, PS_DASHDOT=3, PS_DASHDOTDOT=4,
    #   PS_NULL=5
    #
    #   bits 8-11: PS_ENDCAP_ROUND=0x0000, _SQUARE=0x0100, _FLAT=0x0200
    #   bits 12-15: PS_JOIN_ROUND=0x0000, _BEVEL=0x1000, _MITER=0x2000
    #
    # emfsvg's EMF→SVG renderer emits `stroke-width="1px"` (with the px
    # suffix) AND no linecap/linejoin attrs as the fallback for a NULL
    # pen with a solid brush. When the SVG→EMF side sees that exact
    # form, it round-trips back to a NULL pen to preserve the rendering.
    class Stroke
      END_CAP_BITS = { "butt" => 0x0200, "round" => 0x0000, "square" => 0x0100 }.freeze
      LINE_JOIN_BITS = { "miter" => 0x2000, "round" => 0x0000, "bevel" => 0x1000 }.freeze
      NULL_PEN_WIDTH_SENTINEL = "1px"

      attr_reader :paint, :width, :dash_array, :line_cap, :line_join, :miter_limit, :raw_width,
                  :line_cap_explicit, :line_join_explicit

      def initialize(paint:, width: 1.0, dash_array: nil, line_cap: "round",
                     line_join: "round", miter_limit: 10.0, raw_width: nil,
                     line_cap_explicit: false, line_join_explicit: false)
        @paint = paint
        @width = width.to_f
        @dash_array = dash_array
        @line_cap = line_cap
        @line_join = line_join
        @miter_limit = miter_limit.to_f
        @raw_width = raw_width
        @line_cap_explicit = line_cap_explicit
        @line_join_explicit = line_join_explicit
      end

      def null_pen_sentinel?
        raw_width == NULL_PEN_WIDTH_SENTINEL &&
          !line_cap_explicit &&
          !line_join_explicit
      end

      PS_GEOMETRIC = 0x00010000

      # Pen style bitmask (full 32 bits). Includes:
      #   * dash style (bits 0-7)
      #   * end-cap (bits 8-11)
      #   * line-join (bits 12-15)
      #   * pen type GEOMETRIC (bit 16) — set when width > 1, so
      #     emfsvg's EMF→SVG renderer uses the actual pen.width
      #     instead of hardcoding 1.
      def pen_style
        base = if paint.null? || null_pen_sentinel?
                 5 # PS_NULL
               else
                 dash_style
               end
        type_bit = width > 1.0 && !paint.null? ? PS_GEOMETRIC : 0
        base | type_bit | END_CAP_BITS.fetch(line_cap, 0x0000) | LINE_JOIN_BITS.fetch(line_join, 0x0000)
      end

      def self.parse(stroke:, width:, dash_array:, line_cap:, line_join:, miter_limit: nil)
        new(
          paint: Paint.from_stroke(stroke),
          width: parse_width(width),
          dash_array: parse_dash_array(dash_array),
          line_cap: line_cap || "round",
          line_join: line_join || "round",
          miter_limit: parse_miter_limit(miter_limit),
          raw_width: width,
          line_cap_explicit: !line_cap.nil?,
          line_join_explicit: !line_join.nil?
        )
      end

      def self.parse_miter_limit(value)
        return 10.0 if value.nil? || value.strip.empty?

        Float(value)
      rescue ArgumentError
        10.0
      end

      def self.parse_width(value)
        return 1.0 if value.nil? || value.strip.empty?

        match = value.match(/\A(-?\d+(?:\.\d+)?)/)
        match ? match[1].to_f : 1.0
      end

      # SVG dasharray is a comma/space separated list of lengths; "none"
      # means solid. We map the first length to a discrete dash style:
      # a single length matching roughly the width → PS_DOT, longer →
      # PS_DASH. Anything more complex is approximated as PS_DASH for v1.
      def dash_style
        return 0 if dash_array.nil? || dash_array.empty?

        first = dash_array.first
        return 0 if first.zero?

        first < (width * 2) ? 2 : 1 # PS_DOT=2, PS_DASH=1
      end

      def self.parse_dash_array(value)
        return nil if value.nil? || value.strip == "none" || value.strip.empty?

        parts = value.split(/[\s,]+/).map(&:to_f)
        parts.empty? ? nil : parts
      end
    end
  end
end
