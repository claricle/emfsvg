# frozen_string_literal: true

module Emfsvg
  module Svg
    module Elements
      # <defs>: container for reusable definitions (clipPath, etc.).
      # Children are NOT rendered directly; they are referenced by id.
      class Defs < Element
        ELEMENT_NAME = "defs"
        Element.register("defs", self)

        attr_reader :children

        def initialize(children:)
          @children = children
        end

        def self.from_node(node)
          new(children: node.element_children.map { |c| Element.from_node(c) })
        end
      end
    end
  end
end
