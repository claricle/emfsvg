# frozen_string_literal: true

require "emf"

module Emfsvg
  module Svg
    module Elements
      # <g transform="...">...</g>: groups children with an optional
      # coordinate transform applied to all descendants.
      class Group < Element
        ELEMENT_NAME = "g"
        Element.register("g", self)

        attr_reader :children, :transform_matrix

        def initialize(children:, transform_matrix: Emf::Model::Geometry::Matrix.identity)
          @children = children
          @transform_matrix = transform_matrix
        end

        def transformed?
          !transform_matrix.identity?
        end

        def self.from_node(node)
          children = node.element_children.map { |c| Element.from_node(c) }
          new(children: children,
              transform_matrix: Svg::TransformParser.parse(node["transform"]))
        end
      end
    end
  end
end
