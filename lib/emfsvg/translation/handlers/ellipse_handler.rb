# frozen_string_literal: true

require "emf"

module Emfsvg
  module Translation
    module Handlers
      # Translate <ellipse> to EMR_ELLIPSE.
      class EllipseHandler
        include SharedGdi
        include Emf::Emr::Binary::TypeCodes

        def self.call(element, context)
          new.translate(element, context)
        end

        def translate(element, context)
          with_gdi_state(element, context) do
            box = context.rect_attrs(element.cx - element.rx, element.cy - element.ry,
                                     element.cx + element.rx, element.cy + element.ry)
            context.emit(Emf::Emr::Binary::Records::Ellipse,
                         i_type: ELLIPSE, rcl_box: box)
          end
        end
      end
    end
  end
end
