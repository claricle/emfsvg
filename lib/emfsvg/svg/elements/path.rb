# frozen_string_literal: true

module Emfsvg
  module Svg
    module Elements
      # <path d="..."/>. Stores parsed PathData::Command list.
      class Path < Element
        ELEMENT_NAME = "path"
        Element.register("path", self)

        attr_reader :commands, :fill, :stroke, :clip_path, :line_record_kind, :path_record_kind

        def initialize(commands:, fill:, stroke:, clip_path: nil, line_record_kind: nil, path_record_kind: nil)
          @commands = commands
          @fill = fill
          @stroke = stroke
          @clip_path = clip_path
          @line_record_kind = line_record_kind
          @path_record_kind = path_record_kind
        end

        def self.from_node(node)
          source_tag = yield(node) if block_given?
          new(
            commands: Svg::PathData::Parser.parse(node["d"]),
            line_record_kind: source_tag && canonical_polyline?(node, source_tag) ? :polyline : nil,
            path_record_kind: source_tag && canonical_poly_polygon?(node, source_tag) ? :polypolygon : nil,
            **Stylable.parse_style(node)
          )
        end

        # Only the exact legacy renderer spelling provides record provenance.
        # Ordinary SVG paths keep the existing translation strategy.
        def self.canonical_polyline?(node, source_tag)
          number = "-?\\d+\\.\\d{4}"
          return false unless node["d"]&.match?(/\AM #{number},#{number} L #{number},#{number} \z/)
          return false unless node["stroke"]&.match?(/\A#[0-9A-Fa-f]{6}\z/)
          return false unless node["stroke-width"]&.match?(/\A(?:#{number}|1px)\z/)
          return false unless %w[round square butt].include?(node["stroke-linecap"])
          return false unless %w[round bevel miter].include?(node["stroke-linejoin"])
          return false unless node["fill"] == "none"

          expected = %(<path d="#{node['d']}" stroke="#{node['stroke']}" stroke-width="#{node['stroke-width']}" )
          expected << %(stroke-dasharray="#{node['stroke-dasharray']}" ) if node["stroke-dasharray"]
          expected << %( stroke-linecap="#{node['stroke-linecap']}"  stroke-linejoin="#{node['stroke-linejoin']}" )
          expected << %( stroke-miterlimit="#{node['stroke-miterlimit']}" ) if node["stroke-miterlimit"]
          expected << %(fill="none" />)
          source_tag == expected
        end
        private_class_method :canonical_polyline?

        # PolyPolygon's C renderer has a distinctive fill-first start tag and
        # retains a trailing space after Z. Preserve that record only for the
        # exact spelling emitted by the renderer; ordinary closed paths use
        # Polygon as before.
        def self.canonical_poly_polygon?(node, source_tag)
          number = "-?\\d+\\.\\d{4}"
          return false unless node["d"]&.match?(/\AM #{number},#{number}(?: L #{number},#{number})+ Z \z/)
          return false unless node["fill"]&.match?(/\A#[0-9A-F]{6}\z/)
          return false unless node["stroke"]&.match?(/\A#[0-9A-F]{6}\z/)
          return false unless node["stroke-width"]&.match?(/\A(?:#{number}|1px)\z/)
          return false unless %w[round square butt].include?(node["stroke-linecap"])
          return false unless %w[round bevel miter].include?(node["stroke-linejoin"])
          return false if node["stroke-dasharray"]

          expected = %(<path d="#{node['d']}"  fill="#{node['fill']}" stroke="#{node['stroke']}" )
          expected << %(stroke-width="#{node['stroke-width']}"  stroke-linecap="#{node['stroke-linecap']}" )
          expected << %( stroke-linejoin="#{node['stroke-linejoin']}" )
          if node["stroke-miterlimit"]
            return false unless node["stroke-linejoin"] == "miter"

            expected << %( stroke-miterlimit="#{node['stroke-miterlimit']}" )
          end
          expected << "/>"
          source_tag == expected
        end
        private_class_method :canonical_poly_polygon?
      end
    end
  end
end
