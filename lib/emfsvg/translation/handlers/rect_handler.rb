# frozen_string_literal: true

require "emf"

module Emfsvg
  module Translation
    module Handlers
      # Translate <rect> to EMR_RECTANGLE or EMR_ROUNDRECT.
      class RectHandler
        include SharedGdi
        include Emf::Emr::Binary::TypeCodes

        def self.call(element, context)
          handler = new
          handler.translate(element, context)
        end

        def translate(element, context)
          with_gdi_state(element, context) do
            emit_rect(element, context)
          end
        end

        private

        def emit_rect(element, context)
          box = context.rect_attrs(element.x, element.y,
                                   element.x + element.width,
                                   element.y + element.height)

          if element.rounded?
            # The pinned C renderer emits szlCorner directly as SVG rx/ry.
            corner = context.size_attrs(element.rx, element.ry)
            context.emit(Emf::Emr::Binary::Records::RoundRect,
                         i_type: ROUNDRECT, rcl_box: box, szl_corner: corner)
          else
            context.emit(Emf::Emr::Binary::Records::Rectangle,
                         i_type: RECTANGLE, rcl_box: box)
          end
        end
      end
    end
  end
end
