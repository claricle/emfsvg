# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    module FilledCurvePathActionHelpers
      def records_for(path)
        svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20">#{path}</svg>)
        Emf.parse(Emfsvg.from_svg(svg)).records.map(&:wire)
      end
    end
  end
end
