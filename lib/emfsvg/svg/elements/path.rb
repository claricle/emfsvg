# frozen_string_literal: true

module Emfsvg
  module Svg
    module Elements
      # <path d="..."/>. Stores parsed PathData::Command list.
      class Path < Element
        ELEMENT_NAME = "path"
        Element.register("path", self)

        attr_reader :commands, :fill, :stroke, :clip_path, :line_record_kind

        def initialize(commands:, fill:, stroke:, clip_path: nil, line_record_kind: nil)
          @commands = commands
          @fill = fill
          @stroke = stroke
          @clip_path = clip_path
          @line_record_kind = line_record_kind
        end

        def self.from_node(node)
          new(
            commands: Svg::PathData::Parser.parse(node["d"]),
            line_record_kind: block_given? && canonical_polyline?(node, yield(node)) ? :polyline : nil,
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
      end
    end
  end
end
