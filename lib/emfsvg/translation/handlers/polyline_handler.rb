# frozen_string_literal: true

require "emf"

module Emfsvg
  module Translation
    module Handlers
      # Translate <polyline> to EMR_POLYLINE.
      class PolylineHandler
        include SharedGdi
        include Emf::Emr::Binary::TypeCodes

        def self.call(element, context)
          new.translate(element, context)
        end

        def translate(element, context)
          return if element.points.empty?

          with_gdi_state(element, context) do
            emit_poly(element.points, element, context)
          end
        end

        private

        def emit_poly(points, element, context)
          bounds = bounding_box(points, context)
          wire_points = points.map { |x, y| context.point_attrs(x, y) }
          record_class = if element.is_a?(Svg::Elements::Polygon)
                           Emf::Emr::Binary::Records::Polygon
                         else
                           Emf::Emr::Binary::Records::Polyline
                         end
          i_type = element.is_a?(Svg::Elements::Polygon) ? POLYGON : POLYLINE
          context.emit(record_class,
                       i_type: i_type,
                       rcl_bounds: bounds,
                       cptl: wire_points.size,
                       aptl: wire_points)
        end

        def bounding_box(points, context)
          xs = points.map { |x, _| x }
          ys = points.map { |_, y| y }
          context.rect_attrs(xs.min, ys.min, xs.max, ys.max)
        end
      end
    end
  end
end
