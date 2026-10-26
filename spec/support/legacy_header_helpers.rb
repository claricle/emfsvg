# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    module LegacyHeaderHelpers
      def header_group(inner)
        %(<g transform="translate(0,0)">#{inner}</g>)
      end

      def svg(width, height, transform, inner: "")
        %(<svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}">) \
          "<g transform=\"#{transform}\">#{inner}</g></svg>"
      end

      def header_bounds(svg_string)
        h = Emf.parse(Emfsvg.from_svg(svg_string)).header.bounds
        [h.left, h.top, h.right, h.bottom]
      end
    end
  end
end
