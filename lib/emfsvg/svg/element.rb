# frozen_string_literal: true

module Emfsvg
  module Svg
    # Base value object for an SVG element. Subclasses (Svg::Elements::*)
    # carry typed semantic fields; the base provides a uniform interface
    # for the translation layer's dispatch.
    #
    # Element instances are immutable: built once from a leptris node
    # via the .from_node factory. The node is not retained.
    class Element
      ELEMENT_NAME = "abstract"

      def element_name
        self.class::ELEMENT_NAME
      end

      def children
        []
      end

      # All elements expose `clip_path` (nil by default) so the SharedGdi
      # module can treat every element uniformly. Subclasses with the
      # attribute override via attr_reader.
      def clip_path
        nil
      end

      # Registry: SVG element name -> Element subclass. OCP: register
      # new subclasses via Element.register("rect", Elements::Rect)
      # instead of editing a switch.
      @registry = {}

      class << self
        attr_reader :registry

        def register(element_name, subclass)
          @registry[element_name] = subclass
        end

        def from_node(node)
          subclass = @registry[node.name]
          return subclass.from_node(node) if subclass

          OpenElement.new(name: node.name, children: node.element_children.map do |c|
            from_node(c)
          end)
        end
      end
    end

    # Fallback for unknown SVG element types. Carries the element name
    # so handlers can skip it or warn; carries children so traversal
    # still descends into known subtrees.
    class OpenElement < Element
      ELEMENT_NAME = "open"

      attr_reader :name, :children

      def initialize(name:, children: [])
        @name = name
        @children = children.freeze
      end
    end
  end
end
