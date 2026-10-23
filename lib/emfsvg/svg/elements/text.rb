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

        # The font attributes of a <text> element.
        Font = Struct.new(:family, :point_size, :weight, :style, keyword_init: true)

        attr_reader :x, :y, :content, :font, :text_anchor, :fill, :stroke,
                    :clip_path, :transform_matrix

        def initialize(x:, y:, content:, font:, text_anchor:, fill:, stroke:, clip_path: nil,
                       transform_matrix: Emf::Model::Geometry::Matrix.identity)
          @x = x
          @y = y
          @content = content
          @font = font
          @text_anchor = text_anchor
          @fill = fill
          @stroke = stroke
          @clip_path = clip_path
          @transform_matrix = transform_matrix
        end

        def font_family = font.family

        def font_size = font.point_size

        def font_weight = font.weight

        def font_style = font.style

        def transformed?
          !transform_matrix.identity?
        end

        def self.from_node(node)
          new(
            x: AttributeParser.float(node["x"]),
            y: AttributeParser.float(node["y"]),
            content: node.text,
            font: Font.new(
              family: node["font-family"],
              point_size: AttributeParser.float(node["font-size"], default: 12.0),
              weight: parse_weight(node["font-weight"]),
              style: node["font-style"]
            ),
            text_anchor: node["text-anchor"] || "start",
            transform_matrix: Svg::TransformParser.parse(node["transform"]),
            **Stylable.parse_style(node)
          )
        end

        def self.parse_weight(value)
          return 0 if value.nil?
          return 400 if value == "normal"

          value == "bold" ? 700 : value.to_i
        end

        def italic?
          font_style == "italic"
        end
      end
    end
  end
end
