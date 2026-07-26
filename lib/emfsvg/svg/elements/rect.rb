# frozen_string_literal: true

module Emfsvg
  module Svg
    module Elements
      # <rect x y width height rx ry/>
      # Produces EMR_RECTANGLE (no rx/ry) or EMR_ROUNDRECT (rx/ry present).
      class Rect < Element
        ELEMENT_NAME = "rect"
        Element.register("rect", self)

        attr_reader :x, :y, :width, :height, :rx, :ry, :fill, :stroke, :clip_path

        def initialize(x:, y:, width:, height:, rx:, ry:, fill:, stroke:, clip_path: nil)
          @x = x
          @y = y
          @width = width
          @height = height
          @rx = rx
          @ry = ry
          @fill = fill
          @stroke = stroke
          @clip_path = clip_path
        end

        def self.from_node(node)
          new(
            x: AttributeParser.float(node["x"]),
            y: AttributeParser.float(node["y"]),
            width: AttributeParser.float(node["width"]),
            height: AttributeParser.float(node["height"]),
            rx: AttributeParser.float(node["rx"]),
            ry: AttributeParser.float(node["ry"]),
            **Stylable.parse_style(node)
          )
        end

        def rounded?
          rx.positive? || ry.positive?
        end
      end
    end
  end
end
