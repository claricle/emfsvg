# frozen_string_literal: true

module Emfsvg
  module Translation
    module Handlers
      # Flatten a list of Svg::PathData::Command into a single shape
      # (Polyline/Polygon/PolyBezier) suitable for one EMF record.
      #
      # v1 limitations:
      #   * All commands converted to absolute (relative resolved).
      #   * Arc/quadratic commands approximated as lines (TODO).
      #   * Multiple subpaths merged into one (TODO: PolyPolygon).
      class PathFlattener
        Result = Struct.new(:shape_kind, :points, :bounds, keyword_init: true)

        def self.flatten(commands)
          new.flatten(commands)
        end

        def flatten(commands)
          @cx = 0.0
          @cy = 0.0
          @closed = false
          @has_curve = false
          @points = []
          commands.each { |command| apply(command) }

          Result.new(
            shape_kind: shape_kind(@closed, @has_curve),
            points: @points,
            bounds: bounds_for(@points)
          )
        end

        private

        # Single-use per flatten call: @cx/@cy is the current position.
        # Each command moves it (relative letters add to it) and records
        # the point(s) it reaches.
        def apply(command)
          args = command.args
          case command.letter
          when "M", "L" then go_to(args[0], args[1])
          when "m", "l" then go_to(@cx + args[0], @cy + args[1])
          when "H" then go_to(args[0], @cy)
          when "h" then go_to(@cx + args[0], @cy)
          when "V" then go_to(@cx, args[0])
          when "v" then go_to(@cx, @cy + args[0])
          when "C" then curve_to(args[0], args[1], args[2], args[3], args[4], args[5])
          when "c" then relative_curve_to(args)
          when "Z", "z" then @closed = true
          end
        end

        def go_to(x, y)
          @cx = x
          @cy = y
          @points << [x, y]
        end

        def relative_curve_to(args)
          x = @cx
          y = @cy
          curve_to(x + args[0], y + args[1], x + args[2], y + args[3], x + args[4], y + args[5])
        end

        def curve_to(x1, y1, x2, y2, x, y)
          @has_curve = true
          @points << [x1, y1] << [x2, y2]
          go_to(x, y)
        end

        def shape_kind(closed, has_curve)
          return :polybezier if has_curve

          closed ? :polygon : :polyline
        end

        # Bounds holds raw decimal values (NOT pre-scaled to int). The
        # caller routes them through Context#rect_l so the scaler
        # decides the final int representation.
        Bounds = Struct.new(:left, :top, :right, :bottom, keyword_init: true)

        def bounds_for(points)
          return Bounds.new(left: 0, top: 0, right: 0, bottom: 0) if points.empty?

          left = right = points[0][0]
          top = bottom = points[0][1]
          points.each do |x, y|
            left = x if x < left
            right = x if x > right
            top = y if y < top
            bottom = y if y > bottom
          end
          Bounds.new(left: left, top: top, right: right, bottom: bottom)
        end
      end
    end
  end
end
