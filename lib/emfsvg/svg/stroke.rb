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
      COSMETIC_DASH_PATTERNS = {
        1 => [5, 5], 2 => [1, 1], 3 => [5, 5, 1, 5], 4 => [5, 5, 1, 1, 1, 5]
      }.freeze
      private_constant :COSMETIC_DASH_PATTERNS

      attr_reader :paint, :width, :dash_array, :line_cap, :line_join, :miter_limit, :raw_width,
                  :line_cap_explicit, :line_join_explicit, :null_pen_fallback, :fallback_brush, :canonical_cosmetic_dash

      def initialize(paint:, width: 1.0, dash_array: nil, line_cap: "round",
                     line_join: "round", miter_limit: 10.0, raw_width: nil,
                     line_cap_explicit: false, line_join_explicit: false,
                     null_pen_fallback: true, fallback_brush: nil)
        @paint = paint
        @width = width.to_f
        @dash_array = dash_array
        @line_cap = line_cap
        @line_join = line_join
        @miter_limit = miter_limit.to_f
        @raw_width = raw_width
        @line_cap_explicit = line_cap_explicit
        @line_join_explicit = line_join_explicit
        @null_pen_fallback = null_pen_fallback
        @fallback_brush = fallback_brush
      end

      def null_pen_sentinel?
        raw_width == NULL_PEN_WIDTH_SENTINEL &&
          null_pen_fallback &&
          !line_cap_explicit &&
          !line_join_explicit
      end

      # Recover only the exact unfilled Polyline spelling emitted for these
      # legacy cosmetic pens. Ordinary SVG shares the parsed paint cache.
      def with_canonical_cosmetic_dash(source_tag)
        return self unless %w[1.0000 1px].include?(raw_width) && !paint.null? && dash_array

        number = "-?\\d+\\.\\d{4}"
        point = "#{number},#{number}"
        data = source_tag&.[](/\A<path d="(M #{point}(?: L #{point})+ )"/, 1)
        color = source_tag&.[](/ stroke="(#[0-9A-F]{6})"/, 1)
        return self unless data && color

        lengths = dash_array.map { |length| format("%.4f", length) }.join(",")
        expected = %(<path d="#{data}" stroke="#{color}" stroke-width="#{raw_width}" )
        expected << %(stroke-dasharray="#{lengths}"  stroke-linecap="round"  stroke-linejoin="round" fill="none" />)
        return self unless source_tag == expected

        COSMETIC_DASH_PATTERNS.each do |style, pattern|
          stored_width = dash_array.first / pattern.first
          next unless stored_width >= 1 && stored_width == stored_width.to_i
          next unless dash_array == pattern.map { |length| length * stored_width }

          return dup.tap { |copy| copy.canonical_cosmetic_dash = [stored_width, style].freeze }
        end
        self
      end

      protected

      attr_writer :canonical_cosmetic_dash

      public

      PS_GEOMETRIC = 0x00010000

      # Cosmetic widths are device pixels, independent of logical coordinates.
      def cosmetic_pixel_width?
        raw_width == "1px" && !paint.null? && !null_pen_sentinel?
      end

      # Pen style bitmask (full 32 bits). Includes:
      #   * dash style (bits 0-7)
      #   * end-cap (bits 8-11)
      #   * line-join (bits 12-15)
      #   * pen type GEOMETRIC (bit 16) — set when width > 1 or an
      #     explicit unitless width of 1 must survive SVG round trips.
      def pen_style
        return canonical_cosmetic_dash[1] if canonical_cosmetic_dash

        @pen_style ||= compute_pen_style
      end

      def compute_pen_style
        base = if paint.null? || null_pen_sentinel?
                 5 # PS_NULL
               else
                 dash_style
               end
        type_bit = (width > 1.0 || explicit_unitless_one_width?) && !paint.null? ? PS_GEOMETRIC : 0
        base | type_bit | END_CAP_BITS.fetch(line_cap, 0x0000) | LINE_JOIN_BITS.fetch(line_join, 0x0000)
      end
      private :compute_pen_style

      def self.parse(stroke:, width:, dash_array:, line_cap:, line_join:, miter_limit: nil, fill: nil)
        new(
          paint: Paint.from_stroke(stroke),
          width: parse_width(width),
          dash_array: parse_dash_array(dash_array),
          line_cap: line_cap || "round",
          line_join: line_join || "round",
          miter_limit: parse_miter_limit(miter_limit),
          raw_width: width,
          line_cap_explicit: !line_cap.nil?,
          line_join_explicit: !line_join.nil?,
          null_pen_fallback: fill.nil? || !fill.null?
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

      def explicit_unitless_one_width?
        raw_width.to_s.match?(/\A\s*1(?:\.0+)?\s*\z/)
      end

      def self.parse_dash_array(value)
        return nil if value.nil? || value.strip == "none" || value.strip.empty?

        parts = value.split(/[\s,]+/).map(&:to_f)
        parts.empty? ? nil : parts.freeze
      end
    end
  end
end
