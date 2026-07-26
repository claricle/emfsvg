# frozen_string_literal: true

require "nokogiri"

module Emfsvg
  module Svg
    # Parses an SVG document string into a Svg::Document value object.
    # Nokogiri is the only XML/HTML parser used in this gem.
    #
    # Width/height are coerced to floats (CSS units other than px are
    # out of scope for v1; a numeric value is treated as user units).
    # viewBox is parsed into a 4-tuple [min_x, min_y, width, height].
    module Parser
      module_function

      def call(string)
        doc = Nokogiri::XML(string, &:noblanks)
        root = doc.root
        raise ParseError, "not an SVG document: missing root element" unless root

        Document.new(
          width: parse_dimension(root["width"]),
          height: parse_dimension(root["height"]),
          view_box: parse_view_box(root["viewBox"]),
          root_element: Element.from_node(root)
        )
      end

      def parse_dimension(value)
        return 0.0 if value.nil? || value.empty?

        match = value.match(/\A(-?\d+(?:\.\d+)?)/)
        match ? match[1].to_f : 0.0
      end

      def parse_view_box(value)
        return nil if value.nil? || value.empty?

        parts = value.split(/[\s,]+/).map(&:to_f)
        parts.length == 4 ? parts : nil
      end
    end
  end
end
