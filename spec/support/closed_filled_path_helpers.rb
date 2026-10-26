# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    module ClosedFilledPathHelpers
      def svg_with(path)
        %(<svg xmlns="http://www.w3.org/2000/svg" width="14030.0000" height="9920.0000">#{path}</svg>)
      end
    end
  end
end
