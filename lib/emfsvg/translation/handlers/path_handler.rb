# frozen_string_literal: true

require "emf"

module Emfsvg
  module Translation
    module Handlers
      # Translate <path d="..."> to EMF drawing records.
      #
      # v1 strategy: flatten to absolute, fully-resolved points. Bezier
      # control points are preserved as cubic Beziers; arcs/quads are
      # approximated (TODO). Emits a single PolyBezier record when
      # cubics are present, else Polyline / Polygon.
      class PathHandler
        include SharedGdi
        include Emf::Emr::Binary::TypeCodes

        def self.call(element, context)
          new.translate(element, context)
        end

        def translate(element, context)
          return if element.commands.empty?

          with_gdi_state(element, context) do
            flattened = PathFlattener.flatten(element.commands)
            emit_path(flattened, element, context)
          end
        end

        private

        def emit_path(flattened, _element, context)
          case flattened.shape_kind
          when :polygon then emit_polygon(flattened, context)
          when :polyline then emit_polyline(flattened, context)
          when :polybezier then emit_polybezier(flattened, context)
          end
        end

        def emit_polygon(flattened, context)
          emit_poly(Emf::Emr::Binary::Records::Polygon, POLYGON, flattened, context)
        end

        def emit_polyline(flattened, context)
          emit_poly(Emf::Emr::Binary::Records::Polyline, POLYLINE, flattened, context)
        end

        def emit_polybezier(flattened, context)
          # emfsvg's EMF→SVG renderer prepends `M cur_x,cur_y` before
          # every PolyBezier's `M point[0] C ...`. To make round-trip
          # byte-equal when cur matches point[0], emit a MoveToEx to
          # set the current position to the PolyBezier's first point.
          first = flattened.points.first
          if first
            context.emit(Emf::Emr::Binary::Records::MoveToEx,
                         i_type: MOVETOEX,
                         origin: context.point_attrs(first[0], first[1]))
          end
          emit_poly(Emf::Emr::Binary::Records::PolyBezier, POLYBEZIER, flattened, context)
        end

        def emit_poly(record_class, i_type, flattened, context)
          points = flattened.points.map { |x, y| context.point_attrs(x, y) }
          scaled_bounds = context.rect_attrs(
            flattened.bounds.left, flattened.bounds.top,
            flattened.bounds.right, flattened.bounds.bottom
          )
          context.emit(record_class,
                       i_type: i_type,
                       rcl_bounds: scaled_bounds,
                       cptl: points.size,
                       aptl: points)
        end
      end
    end
  end
end
