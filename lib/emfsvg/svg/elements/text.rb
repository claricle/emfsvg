# frozen_string_literal: true

require "emf"

module Emfsvg
  module Svg
    module Elements
      # <text x y font-family font-size font-weight fill>content</text>
      # v1: single run, no <tspan>, no textPath. Content is read from the
      # element's text node.
      class Text < Element
        ELEMENT_NAME = "text"
        Element.register("text", self)

        attr_reader :x, :y, :content, :font_family, :font_size, :font_weight,
                    :font_style, :text_anchor, :fill, :stroke, :clip_path,
                    :transform_matrix

        def initialize(x:, y:, content:, font_family:, font_size:, font_weight:,
                       font_style:, text_anchor:, fill:, stroke:, clip_path: nil,
                       transform_matrix: Emf::Model::Geometry::Matrix.identity)
          @x = x
          @y = y
          @content = content
          @font_family = font_family
          @font_size = font_size
          @font_weight = font_weight
          @font_style = font_style
          @text_anchor = text_anchor
          @fill = fill
          @stroke = stroke
          @clip_path = clip_path
          @transform_matrix = transform_matrix
        end

        def transformed?
          !transform_matrix.identity?
        end

        def self.from_node(node)
          new(
            x: AttributeParser.float(node["x"]),
            y: AttributeParser.float(node["y"]),
            content: node.text,
            font_family: node["font-family"],
            font_size: AttributeParser.float(node["font-size"], default: 12.0),
            font_weight: parse_weight(node["font-weight"]),
            font_style: node["font-style"],
            text_anchor: node["text-anchor"] || "start",
            transform_matrix: Svg::TransformParser.parse(node["transform"]),
            **Stylable.parse_style(node)
          )
        end

        def self.parse_weight(value)
          return 400 if value.nil? || value == "normal"

          value == "bold" ? 700 : value.to_i
        end

        def italic?
          font_style == "italic"
        end
      end
    end
  end
end
