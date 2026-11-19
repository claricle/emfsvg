# frozen_string_literal: true

module Emfsvg
  module Svg
    module Elements
      # <pattern id="..."> paint server. A pattern is a reusable fill
      # resource referenced by id (`fill="url(#id)""); its content is
      # never rendered directly.
      #
      # Only the raster flavor is modeled: a pattern whose content is a
      # single embedded raster <image> maps 1:1 to an EMF DIB pattern
      # brush (EMR_CREATEDIBPATTERNBRUSHPT). Patterns with vector
      # content, gradients, or tiles get no brush and degrade to the
      # fill's fallback color at translation time.
      #
      # Geometry attributes (width/height/viewBox/patternUnits) are
      # intentionally not retained: an EMF pattern brush tiles the DIB
      # at the device origin, so per-tile SVG geometry has no faithful
      # EMF counterpart to carry.
      class Pattern < Element
        ELEMENT_NAME = "pattern"
        Element.register("pattern", self)

        attr_reader :id, :image

        def initialize(id:, image: nil)
          @id = id
          @image = image
        end

        def self.from_node(node)
          image_node = node.element_children.find { |child| child.name == "image" }
          new(id: node["id"], image: image_node && Image.from_node(image_node))
        end
      end
    end
  end
end
