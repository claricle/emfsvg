# frozen_string_literal: true

require "emf"

module Emfsvg
  module Translation
    module Handlers
      # Translate <line> to MoveToEx + LineTo.
      class LineHandler
        include SharedGdi
        include Emf::Emr::Binary::TypeCodes

        def self.call(element, context)
          new.translate(element, context)
        end

        def translate(element, context)
          with_gdi_state(element, context) do
            context.emit(Emf::Emr::Binary::Records::MoveToEx,
                         i_type: MOVETOEX,
                         origin: context.point_l(element.x1, element.y1))
            context.emit(Emf::Emr::Binary::Records::LineTo,
                         i_type: LINETO,
                         origin: context.point_l(element.x2, element.y2))
          end
        end
      end
    end
  end
end
