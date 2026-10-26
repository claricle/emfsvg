# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    module CanonicalCosmeticDashConversion
      def dash_conversion(path, fixed: false)
        control = '<path d="M 1,2 L 3,4" fill="none" stroke="#0000FF" stroke-width="1px" stroke-linecap="round"/>'
        svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="14030" height="9920">#{path}#{control if fixed}</svg>)
        bytes = Emfsvg.from_svg(svg)
        parsed = Emf.parse(bytes)
        expect(parsed.errors).to be_empty
        records = parsed.records.map(&:wire)
        [records.grep(Emf::Emr::Binary::Records::CreatePen), Emfsvg.from_bytes(bytes), records]
      end
    end
  end
end
