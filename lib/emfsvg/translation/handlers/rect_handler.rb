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

          if raster_fill?(element)
            # Rectangle's NULL-pen fallback adds a brush-colored outline.
            # A source-free raster fill retains SVG's fill-only boundary.
            position = context.point_attrs(element.x, element.y)
            size = context.size_attrs(element.width, element.height)
            context.emit(Emf::Emr::Binary::Records::BitBlt,
                         i_type: BITBLT, rcl_bounds: box,
                         x_dest: position[:x], y_dest: position[:y],
                         cx_dest: size[:cx], cy_dest: size[:cy],
                         dw_rop: 0x00F00021, cb_bits_src: 0)
          elsif element.rounded?
            # The pinned C renderer emits szlCorner directly as SVG rx/ry.
            corner = context.size_attrs(element.rx, element.ry)
            context.emit(Emf::Emr::Binary::Records::RoundRect,
                         i_type: ROUNDRECT, rcl_box: box, szl_corner: corner)
          else
            context.emit(Emf::Emr::Binary::Records::Rectangle,
                         i_type: RECTANGLE, rcl_box: box)
          end
        end

        def raster_fill?(element)
          !element.rounded? && element.clip_path.nil? &&
            element.stroke.paint.null? && element.fill.style == Svg::Paint::SOLID
        end
      end
    end
  end
end
