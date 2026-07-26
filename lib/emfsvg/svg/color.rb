# frozen_string_literal: true

module Emfsvg
  module Svg
    # SVG color value object. Holds an RGB triplet (0..255 each) or
    # represents a "null" color (fill="none" / stroke="none").
    #
    # Parses CSS color syntax:
    #   * #RGB / #RRGGBB hex
    #   * rgb(r, g, b) functional
    #   * CSS Level 1+2 named colors (17 basic)
    #
    # Anything else raises Emfsvg::FormatError. The translation layer
    # relies on a normalized RGB triplet — no transparency, no currentColor.
    class Color
      attr_reader :red, :green, :blue

      def initialize(red:, green:, blue:)
        @red = clamp(red)
        @green = clamp(green)
        @blue = clamp(blue)
      end

      def null?
        false
      end

      def to_emf_wire
        Emf::Model::Geometry::Color.new(red: red, green: green, blue: blue)
      end

      def ==(other)
        other.is_a?(self.class) && red == other.red && green == other.green && blue == other.blue
      end
      alias eql? ==

      def hash
        [self.class, red, green, blue].hash
      end

      NULL = NullColor = Class.new do
        def null? = true
        def red = 0
        def green = 0
        def blue = 0
        def to_emf_wire = Emf::Model::Geometry::Color.new(red: 0, green: 0, blue: 0)
        def ==(other) = other.is_a?(self.class)
        alias_method :eql?, :==
        def hash = NullColor.hash
      end.new.freeze

      NAMED_COLORS = {
        "black" => [0x00, 0x00, 0x00],
        "silver" => [0xC0, 0xC0, 0xC0],
        "gray" => [0x80, 0x80, 0x80],
        "grey" => [0x80, 0x80, 0x80],
        "white" => [0xFF, 0xFF, 0xFF],
        "maroon" => [0x80, 0x00, 0x00],
        "red" => [0xFF, 0x00, 0x00],
        "purple" => [0x80, 0x00, 0x80],
        "fuchsia" => [0xFF, 0x00, 0xFF],
        "magenta" => [0xFF, 0x00, 0xFF],
        "green" => [0x00, 0x80, 0x00],
        "lime" => [0x00, 0xFF, 0x00],
        "olive" => [0x80, 0x80, 0x00],
        "yellow" => [0xFF, 0xFF, 0x00],
        "navy" => [0x00, 0x00, 0x80],
        "blue" => [0x00, 0x00, 0xFF],
        "teal" => [0x00, 0x80, 0x80],
        "aqua" => [0x00, 0xFF, 0xFF],
        "cyan" => [0x00, 0xFF, 0xFF]
      }.freeze

      def self.parse(value)
        return NULL if value.nil? || value.strip == "none" || value.strip.empty?

        v = value.strip
        if (m = v.match(/\A#([0-9a-fA-F]{3})\z/))
          expand_short_hex(m[1])
        elsif (m = v.match(/\A#([0-9a-fA-F]{6})\z/))
          new(red: m[1][0, 2].to_i(16), green: m[1][2, 2].to_i(16), blue: m[1][4, 2].to_i(16))
        elsif (m = v.match(/\Argb\(\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(-?\d+)\s*\)\z/i))
          new(red: m[1].to_i, green: m[2].to_i, blue: m[3].to_i)
        elsif NAMED_COLORS.key?(v.downcase)
          r, g, b = NAMED_COLORS[v.downcase]
          new(red: r, green: g, blue: b)
        else
          raise FormatError, "unsupported SVG color: #{value.inspect}"
        end
      end

      def self.expand_short_hex(digits)
        new(red: (digits[0] * 2).to_i(16),
            green: (digits[1] * 2).to_i(16),
            blue: (digits[2] * 2).to_i(16))
      end

      private

      def clamp(byte)
        byte.to_i.clamp(0, 255)
      end
    end
  end
end
