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

      # The ColorRef reserved byte emfsvg has always written for a colour.
      WIRE_RESERVED = 255

      # Attribute-hash form of #to_emf_wire(...).to_wire: a record field
      # accepts it and builds the ColorRef in place, without first
      # constructing a model colour and a wire object that the record
      # would only copy.
      #
      # A Color never changes, so the one frozen Hash is returned each time.
      def wire_attrs
        @wire_attrs ||= { red: red, green: green, blue: blue, reserved: WIRE_RESERVED }.freeze
      end

      def ==(other)
        other.is_a?(self.class) && red == other.red && green == other.green && blue == other.blue
      end
      alias eql? ==

      def hash
        [self.class, red, green, blue].hash
      end

      NULL_WIRE_ATTRS = { red: 0, green: 0, blue: 0, reserved: WIRE_RESERVED }.freeze
      private_constant :NULL_WIRE_ATTRS

      NULL = NullColor = Class.new do
        def null? = true
        def red = 0
        def green = 0
        def blue = 0
        def to_emf_wire = Emf::Model::Geometry::Color.new(red: 0, green: 0, blue: 0)
        def wire_attrs = NULL_WIRE_ATTRS
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

      HEX3_RE = /\A#\h{3}\z/
      HEX6_RE = /\A#\h{6}\z/
      RGB_RE = /\Argb\(\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(-?\d+)\s*\)\z/i

      def self.parse(value)
        return NULL if value.nil?

        v = value.strip
        return NULL if v.empty? || v == "none"

        if v.match?(HEX3_RE)
          expand_short_hex(v[1, 3])
        elsif v.match?(HEX6_RE)
          rgb = v[1, 6].to_i(16)
          new(red: rgb >> 16, green: (rgb >> 8) & 0xFF, blue: rgb & 0xFF)
        elsif (m = RGB_RE.match(v))
          new(red: m[1].to_i, green: m[2].to_i, blue: m[3].to_i)
        elsif (rgb = NAMED_COLORS[v.downcase])
          new(red: rgb[0], green: rgb[1], blue: rgb[2])
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
