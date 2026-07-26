# frozen_string_literal: true

module Emfsvg
  module Svg
    module Elements
      # <polyline points="x1,y1 x2,y2 ..."/>
      class Polyline < Element
        ELEMENT_NAME = "polyline"
        Element.register("polyline", self)

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
