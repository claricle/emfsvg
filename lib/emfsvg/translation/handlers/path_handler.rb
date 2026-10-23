# frozen_string_literal: true

require "emf"

module Emfsvg
  module Translation
    module Handlers
      # Translate <path d="..."> to EMF drawing records.
      #
      # v1 strategy: flatten to absolute, fully-resolved points. Bezier
      # control points are preserved as cubic Beziers; arcs/quads remain
      # unsupported. Separate figures retain their closure and order.
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
            emit_subpaths(flattened, context)
          end
        end

        private

        def emit_subpaths(subpaths, context)
          kinds = subpaths.map(&:shape_kind).uniq
          if subpaths.size > 1 && kinds.size == 1 && %i[polygon polyline].include?(kinds.first)
            emit_multi(subpaths, kinds.first == :polygon, context)
          elsif single_line_path?(subpaths)
            subpaths.first.segments.each { |letter, points| emit_segment(letter, points, subpaths.first, context) }
          elsif subpaths.size > 1 || kinds == [:path]
            emit_figures(subpaths, context)
          else
            flattened = subpaths.first
            case flattened.shape_kind
            when :polygon then emit_polygon(flattened, context)
            when :polyline then emit_polyline(flattened, context)
            when :polybezier then emit_polybezier(flattened, context)
            end
          end
        end

        def single_line_path?(subpaths)
          return false unless subpaths.size == 1

          segments = subpaths.first.segments
          segments.size == 2 && segments.first.first == "M" &&
            %w[L H V].include?(segments.last.first)
        end

        def emit_multi(subpaths, closed, context)
          points = subpaths.flat_map(&:points).map { |x, y| context.point_attrs(x, y) }
          context.emit(closed ? Emf::Emr::Binary::Records::PolyPolygon : Emf::Emr::Binary::Records::PolyPolyline,
                       i_type: closed ? POLYPOLYGON : POLYPOLYLINE,
                       rcl_bounds: combined_bounds(subpaths, context),
                       n_polys: subpaths.size, c_ptl_total: points.size,
                       a_poly_counts: subpaths.map { |path| path.points.size }, aptl: points)
        end

        def emit_figures(subpaths, context)
          context.emit(Emf::Emr::Binary::Records::BeginPath, i_type: BEGINPATH)
          subpaths.each do |path|
            path.segments.each { |letter, points| emit_segment(letter, points, path, context) }
          end
          context.emit(Emf::Emr::Binary::Records::EndPath, i_type: ENDPATH)
          context.emit(Emf::Emr::Binary::Records::StrokeAndFillPath,
                       i_type: STROKEANDFILLPATH, rcl_bounds: combined_bounds(subpaths, context))
        end

        def emit_segment(letter, points, path, context)
          case letter
          when "M", "L", "H", "V"
            context.emit(letter == "M" ? Emf::Emr::Binary::Records::MoveToEx : Emf::Emr::Binary::Records::LineTo,
                         i_type: letter == "M" ? MOVETOEX : LINETO,
                         origin: context.point_attrs(*points.first))
          when "C"
            curve = PathFlattener::Result.new(points: points, bounds: path.bounds)
            emit_poly(Emf::Emr::Binary::Records::PolyBezierTo, POLYBEZIERTO, curve, context)
          when "Z"
            context.emit(Emf::Emr::Binary::Records::CloseFigure, i_type: CLOSEFIGURE)
          end
        end

        def combined_bounds(subpaths, context)
          bounds = subpaths.map(&:bounds)
          context.rect_attrs(bounds.map(&:left).min, bounds.map(&:top).min,
                             bounds.map(&:right).max, bounds.map(&:bottom).max)
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
