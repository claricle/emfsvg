# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    module TextAlignmentHelpers
      def roundtrip_texts(texts)
        bytes = Emfsvg.from_svg(<<~SVG)
          <svg xmlns="http://www.w3.org/2000/svg" width="800" height="600">
            #{texts}
          </svg>
        SVG
        parsed = Emf.parse(bytes)
        expect(parsed.errors).to be_empty
        output = Leptris::XML.parse(Emfsvg.from_bytes(bytes))
        [parsed, output.xpath("//*[local-name()='text']")]
      end
    end
  end
end
