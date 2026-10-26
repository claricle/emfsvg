# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    module PolybezierPathHelpers
      def roundtrip_path(data, fill: "none")
        bytes = Emfsvg.from_svg(<<~SVG)
          <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
            <path d="#{data}" fill="#{fill}" stroke="#000000"/>
          </svg>
        SVG
        parsed = Emf.parse(bytes)
        expect(parsed.errors).to be_empty
        output = Emfsvg.from_bytes(bytes)
        [parsed.records.map(&:wire), output, Leptris::XML.parse(output).xpath("//*[local-name()='path']")]
      end
    end
  end
end
