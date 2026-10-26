# frozen_string_literal: true

require "emf"
require_relative "../local_origin"

module Emfsvg
  module Translation
    module Handlers
      # Translate <path d="..."> to EMF drawing records.
      #
      # v1 strategy: flatten to absolute, fully-resolved points. Bezier
      # control points and canonical circular arcs are preserved; other
      # arcs and quads remain unsupported. Separate figures retain their closure and order.
      class PathHandler
        include SharedGdi
        include Emf::Emr::Binary::TypeCodes

        def self.call(element, context)
          new.translate(element, context)
        end

        def translate(element, context)
          return if element.commands.empty? && element.path_record_kind != :stroke_path

          with_gdi_state(element, context) do
            context.with_local_origin(LocalOrigin.for_path(element, context.scaler)) do
              translate_geometry(element, context)
            end
          end
        end

        private

        def translate_geometry(element, context)
          if %i[arc chord pie].include?(element.path_record_kind)
            arc = CircularArc.from_commands(element.commands, kind: element.path_record_kind)
            if element.path_record_kind == :pie
              arc ||= MappedPie.from_commands(element.commands,
                                              scaler: context.scaler)
            end
          end
          if arc&.safe_for?(context)
            arc.emit(context)
            return
          end

          flattened = PathFlattener.flatten(element.commands,
                                            preserve_initial_line: element.path_record_kind == :stroke_path)
          if element.path_record_kind == :bitblt
            emit_bitblt(flattened.first, context)
            return
          end
          return emit_current_curve(flattened, context) if element.path_record_kind == :polybezier_to
          return emit_current_polyline(flattened.first, context) if element.line_record_kind == :polyline_to

          if %i[end_path fill_path stroke_path stroke_and_fill_path].include?(element.path_record_kind)
            emit_figures(flattened, context, stroke_null: element.stroke.paint.null?, unfilled: element.fill.null?,
                                             pending: element.path_record_kind == :end_path)
            return
          end
          emit_subpaths(flattened, context,
                        unfilled: element.fill.null?, stroke_null: element.stroke.paint.null?,
                        line_record_kind: element.line_record_kind,
                        path_record_kind: element.path_record_kind)
        end

        def emit_bitblt(path, context)
          left, top = path.points.first
          right, bottom = path.points[2]
          position = context.point_attrs(left, top)
          size = context.size_attrs(right - left, bottom - top)
          context.emit(Emf::Emr::Binary::Records::BitBlt,
                       i_type: BITBLT, rcl_bounds: context.rect_attrs(left, top, right, bottom),
                       x_dest: position[:x], y_dest: position[:y],
                       cx_dest: size[:cx], cy_dest: size[:cy],
                       dw_rop: 0x00F00021, cb_bits_src: 0)
        end

        def emit_subpaths(subpaths, context, unfilled:, stroke_null:, line_record_kind:, path_record_kind:)
          kinds = subpaths.map(&:shape_kind).uniq
          if unfilled && prefixed_polybezier?(subpaths)
            first = subpaths.first.points.first
            context.emit(Emf::Emr::Binary::Records::MoveToEx, i_type: MOVETOEX,
                                                              origin: context.point_attrs(*first))
            emit_poly(Emf::Emr::Binary::Records::PolyBezier, POLYBEZIER, subpaths.last, context)
          elsif subpaths.size > 1 && kinds.size == 1 && %i[polygon polyline].include?(kinds.first)
            emit_multi(subpaths, kinds.first == :polygon, context)
          elsif canonical_poly_polygon?(subpaths, path_record_kind, kinds)
            emit_multi(subpaths, true, context)
          elsif line_record_kind != :polyline && single_line_path?(subpaths)
            subpaths.first.segments.each { |letter, points| emit_segment(letter, points, subpaths.first, context) }
          elsif subpaths.size > 1 || kinds == [:path]
            emit_figures(subpaths, context, stroke_null: stroke_null, unfilled: unfilled)
          else
            flattened = subpaths.first
            case flattened.shape_kind
            when :polygon then emit_polygon(flattened, context)
            when :polyline then emit_polyline(flattened, context)
            when :polybezier then emit_polybezier(flattened, context)
            end
          end
        end

        def prefixed_polybezier?(subpaths)
          subpaths.size == 2 && subpaths.first.segments.map(&:first) == ["M"] &&
            subpaths.last.shape_kind == :polybezier
        end

        def single_line_path?(subpaths)
          return false unless subpaths.size == 1

          segments = subpaths.first.segments
          segments.size == 2 && segments.first.first == "M" &&
            %w[L H V].include?(segments.last.first)
        end

        def canonical_poly_polygon?(subpaths, path_record_kind, kinds)
          path_record_kind == :polypolygon && subpaths.size == 1 && kinds == [:polygon]
        end

        def emit_multi(subpaths, closed, context)
          points = subpaths.flat_map(&:points).map { |x, y| context.point_attrs(x, y) }
          context.emit(closed ? Emf::Emr::Binary::Records::PolyPolygon : Emf::Emr::Binary::Records::PolyPolyline,
                       i_type: closed ? POLYPOLYGON : POLYPOLYLINE,
                       rcl_bounds: combined_bounds(subpaths, context),
                       n_polys: subpaths.size, c_ptl_total: points.size,
                       a_poly_counts: subpaths.map { |path| path.points.size }, aptl: points)
        end

        def emit_current_curve(subpaths, context)
          subpaths.each do |path|
            context.emit(Emf::Emr::Binary::Records::MoveToEx, i_type: MOVETOEX,
                                                              origin: context.point_attrs(*path.points.first))
            emit_polybezier_to(path, context)
          end
        end

        def emit_polybezier_to(path, context)
          curve = PathFlattener::Result.new(points: path.points.drop(1), bounds: path.bounds)
          emit_poly(Emf::Emr::Binary::Records::PolyBezierTo, POLYBEZIERTO, curve, context)
        end

        def emit_figures(subpaths, context, stroke_null:, unfilled:, pending: false)
          context.emit(Emf::Emr::Binary::Records::BeginPath, i_type: BEGINPATH)
          if pending && subpaths.size > 1 && subpaths.all? { |path| path.shape_kind == :polygon }
            emit_multi(subpaths, true, context)
          else
            subpaths.each do |path|
              path.segments.each { |letter, points| emit_segment(letter, points, path, context) }
            end
          end
          context.emit(Emf::Emr::Binary::Records::EndPath, i_type: ENDPATH)
          return if pending

          action, i_type = if stroke_null && !unfilled
                             [Emf::Emr::Binary::Records::FillPath, FILLPATH]
                           elsif unfilled && !stroke_null
                             [Emf::Emr::Binary::Records::StrokePath, STROKEPATH]
                           else
                             [Emf::Emr::Binary::Records::StrokeAndFillPath, STROKEANDFILLPATH]
                           end
          context.emit(action, i_type: i_type, rcl_bounds: combined_bounds(subpaths, context))
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
          return context.rect_attrs(0, 0, 0, 0) if subpaths.empty?

          bounds = subpaths.map(&:bounds)
          context.rect_attrs(bounds.map(&:left).min, bounds.map(&:top).min,
                             bounds.map(&:right).max, bounds.map(&:bottom).max)
        end

        def emit_polygon(flattened, context)
          emit_poly(Emf::Emr::Binary::Records::Polygon, POLYGON, flattened, context)
        end

        def emit_current_polyline(path, context)
          context.emit(Emf::Emr::Binary::Records::MoveToEx, i_type: MOVETOEX,
                                                            origin: context.point_attrs(*path.points.first))
          line = PathFlattener::Result.new(points: path.points.drop(1), bounds: path.bounds)
          emit_poly(Emf::Emr::Binary::Records::PolylineTo, POLYLINETO, line, context)
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
