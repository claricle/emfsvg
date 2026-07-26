# frozen_string_literal: true

module Emfsvg
  module Svg
    module Elements
      # <polygon points="x1,y1 x2,y2 ..."/> — closed polyline.
      class Polygon < Element
        ELEMENT_NAME = "polygon"
        Element.register("polygon", self)

        attr_reader :points, :fill, :stroke, :clip_path

        def initialize(points:, fill:, stroke:, clip_path: nil)
          @points = points
          @fill = fill
          @stroke = stroke
          @clip_path = clip_path
        end

        def self.from_node(node)
          new(
            points: AttributeParser.points(node["points"]),
            **Stylable.parse_style(node)
          )
        end
      end
    end
  end
end
