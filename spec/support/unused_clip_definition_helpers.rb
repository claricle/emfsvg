# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    module UnusedClipDefinitionHelpers
      def convert(body)
        bytes = Emfsvg.from_svg(%(<svg width="40" height="40">#{body}</svg>))
        [Emfsvg.from_bytes(bytes), Emf.parse(bytes).records.map(&:wire)]
      end
    end
  end
end
