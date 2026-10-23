# frozen_string_literal: true

module Emfsvg
  module Svg
    module Elements
      # Common presentation attribute parsing shared by every shape.
      # Module function — call as `Stylable.parse_style(node)` from
      # an Element subclass's `.from_node` factory.
      module Stylable
        module_function

        def parse_style(node)
          fill = Svg::Paint.from_fill(node["fill"])
          {
            fill: fill,
            stroke: Svg::Stroke.parse(
              stroke: node["stroke"],
              width: node["stroke-width"],
              dash_array: node["stroke-dasharray"],
              line_cap: node["stroke-linecap"],
              line_join: node["stroke-linejoin"],
              miter_limit: node["stroke-miterlimit"],
              fill: fill
            ),
            clip_path: node["clip-path"]
          }
        end
      end
    end
  end
end
