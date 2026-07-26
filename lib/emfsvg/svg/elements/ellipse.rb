# frozen_string_literal: true

module Emfsvg
  module Svg
    module Elements
      # <ellipse cx cy rx ry/>
      class Ellipse < Element
        ELEMENT_NAME = "ellipse"
        Element.register("ellipse", self)

        attr_reader :cx, :cy, :rx, :ry, :fill, :stroke, :clip_path

        def initialize(cx:, cy:, rx:, ry:, fill:, stroke:, clip_path: nil)
          @cx = cx
          @cy = cy
          @rx = rx
          @ry = ry
          @fill = fill
          @stroke = stroke
          @clip_path = clip_path
        end

        def self.from_node(node)
          new(
            cx: AttributeParser.float(node["cx"]),
            cy: AttributeParser.float(node["cy"]),
            rx: AttributeParser.float(node["rx"]),
            ry: AttributeParser.float(node["ry"]),
            **Stylable.parse_style(node)
          )
        end
      end
    end
  end
end
