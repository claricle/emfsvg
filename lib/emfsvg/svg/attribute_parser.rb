# frozen_string_literal: true

module Emfsvg
  module Svg
    # Helpers for parsing common SVG attribute formats (numbers, points,
    # path data). Used by Element subclasses.
    module AttributeParser
      module_function

      def float(value, default: 0.0)
        return default if value.nil? || value.strip.empty?

        match = value.strip.match(/\A(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)/)
        match ? match[1].to_f : default
      end

      def integer(value, default: 0)
        float(value, default: default.to_f).to_i
      end

      # Parse a points list like "1,2 3,4 5,6" into an array of [x, y]
      # pairs.
      def points(value)
        return [] if value.nil? || value.strip.empty?

        nums = value.strip.split(/[\s,]+/).map(&:to_f)
        nums.each_slice(2).to_a
      end
    end
  end
end
