# frozen_string_literal: true

module Emfsvg
  module Svg
    module Elements
      # <line x1 y1 x2 y2/>
      class Line < Element
        ELEMENT_NAME = "line"
        Element.register("line", self)

        attr_reader :x1, :y1, :x2, :y2, :fill, :stroke, :clip_path

        def initialize(x1:, y1:, x2:, y2:, fill:, stroke:, clip_path: nil)
          @x1 = x1
          @y1 = y1
          @x2 = x2
          @y2 = y2
          @fill = fill
          @stroke = stroke
          @clip_path = clip_path
        end

        def self.from_node(node)
          new(
            x1: AttributeParser.float(node["x1"]),
            y1: AttributeParser.float(node["y1"]),
            x2: AttributeParser.float(node["x2"]),
            y2: AttributeParser.float(node["y2"]),
            **Stylable.parse_style(node)
          )
        end
      end
    end
  end
end
