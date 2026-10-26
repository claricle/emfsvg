# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    module CosmeticDashParityHelpers
      def ellipse_svg(width:, dash:, coordinate: "10")
        <<~SVG
          <svg xmlns="http://www.w3.org/2000/svg" width="30" height="30">
            <ellipse cx="#{coordinate}" cy="10" rx="5" ry="4" fill="none"
                     stroke="#000080" stroke-width="#{width}" stroke-dasharray="#{dash}"
                     stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        SVG
      end

      def rendered_ellipse(bytes)
        Leptris::XML.parse(Emfsvg.from_bytes(bytes)).at_xpath("//*[local-name()='ellipse']")
      end
    end
  end
end
