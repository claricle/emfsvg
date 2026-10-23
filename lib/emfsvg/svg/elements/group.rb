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

        # Exact literal libemf2svg emits as the header group of a
        # broken-Y (Sparx/Wine) metafile. Not valid SVG translate syntax.
        LEGACY_BROKEN_Y_TRANSFORM = "translate(0.0000, 0.00 00)"

        attr_reader :children, :transform_matrix

        def initialize(children:, transform_matrix: Emf::Model::Geometry::Matrix.identity,
                       legacy_broken_y: false)
          @children = children
          @transform_matrix = transform_matrix
          @legacy_broken_y = legacy_broken_y
        end

        # True when the source transform was exactly the legacy literal.
        def legacy_broken_y?
          @legacy_broken_y
        end

        def transformed?
          !transform_matrix.identity?
        end

        def self.from_node(node)
          children = node.element_children.map { |c| Element.from_node(c) }
          new(children: children,
              transform_matrix: Svg::TransformParser.parse(node["transform"]),
              legacy_broken_y: node["transform"] == LEGACY_BROKEN_Y_TRANSFORM)
        end
      end
    end
  end
end
