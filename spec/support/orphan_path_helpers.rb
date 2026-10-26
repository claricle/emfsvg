# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    module OrphanPathHelpers
      def source(path)
        %(<svg xmlns="http://www.w3.org/2000/svg" width="30" height="30">#{path}</svg>)
      end

      def path(data)
        [
          %(<path d="#{data}" stroke="#000000" stroke-width="1.0000" ),
          %( stroke-linecap="round"  stroke-linejoin="round" fill="none" />)
        ].join
      end
    end
  end
end
