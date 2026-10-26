# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    module SvgCoordinateScalingHelpers
      def translated_svg(content)
        Emfsvg.from_svg(%(<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">#{content}</svg>))
      end
    end
  end
end
