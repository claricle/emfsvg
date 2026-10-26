# frozen_string_literal: true

require "leptris"

module Emfsvg
  module Svg
    # Parses an SVG document string into a Svg::Document value object.
    # leptris is the only XML parser used in this gem.
    #
    # Width/height are coerced to floats (CSS units other than px are
    # out of scope for v1; a numeric value is treated as user units).
    # viewBox is parsed into a 4-tuple [min_x, min_y, width, height].
    module Parser
      module_function

      def call(string)
        doc = begin
          Leptris::XML.parse(string, options: Leptris::XML::ParseOptions.noblanks)
        rescue Leptris::XML::ParseError
          raise ParseError, "not an SVG document: unparseable content"
        end
        root = doc.root
        raise ParseError, "not an SVG document: missing root element" unless root

        source = string.b
        Document.new(
          width: parse_dimension(root["width"]),
          height: parse_dimension(root["height"]),
          view_box: parse_view_box(root["viewBox"]),
          root_element: Element.from_node(root) { |node| source_tag(source, node) }
        )
      end

      # Node serialization normalizes spacing; the original start tag carries
      # the canonical renderer's distinction between Polyline and LineTo.
      def source_tag(string, node)
        string.match(/\G<(?:path|rect)\b(?:[^"'>]|"[^"]*"|'[^']*')*>/m, node.byte_offset)&.to_s
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
