# frozen_string_literal: true

module Emfsvg
  module Svg
    module Elements
      # <path d="..."/>. Stores parsed PathData::Command list.
      class Path < Element
        ELEMENT_NAME = "path"
        Element.register("path", self)

        attr_reader :commands, :fill, :stroke, :clip_path

        def initialize(commands:, fill:, stroke:, clip_path: nil)
          @commands = commands
          @fill = fill
          @stroke = stroke
          @clip_path = clip_path
        end

        def self.from_node(node)
          new(
            commands: Svg::PathData::Parser.parse(node["d"]),
            **Stylable.parse_style(node)
          )
        end
      end
    end
  end
end
