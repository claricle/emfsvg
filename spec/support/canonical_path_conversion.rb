# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    module CanonicalPathConversion
      def convert(path)
        svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="14030" height="9920">#{path}</svg>)
        bytes = Emfsvg.from_svg(svg)
        [Emf.parse(bytes).records.map(&:wire), Emfsvg.from_bytes(bytes)]
      end
    end
  end
end
