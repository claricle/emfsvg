# frozen_string_literal: true

module Emfsvg
  module Svg
    module Elements
      # <circle cx cy r/> — equivalent to <ellipse> with rx=ry=r.
      class Circle < Element
        ELEMENT_NAME = "circle"
        Element.register("circle", self)

        attr_reader :cx, :cy, :r, :fill, :stroke, :clip_path

        def initialize(cx:, cy:, r:, fill:, stroke:, clip_path: nil)
          @cx = cx
          @cy = cy
          @r = r
          @fill = fill
          @stroke = stroke
          @clip_path = clip_path
        end

        def self.from_node(node)
          new(
            cx: AttributeParser.float(node["cx"]),
            cy: AttributeParser.float(node["cy"]),
            r: AttributeParser.float(node["r"]),
            **Stylable.parse_style(node)
          )
        end

        def to_ellipse
          Ellipse.new(cx: cx, cy: cy, rx: r, ry: r, fill: fill, stroke: stroke,
                      clip_path: clip_path)
        end
      end
    end
  end
end
