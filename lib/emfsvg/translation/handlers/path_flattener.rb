# frozen_string_literal: true

module Emfsvg
  module Translation
    module Handlers
      # Resolve supported commands to absolute points without joining figures.
      class PathFlattener
        Result = Struct.new(:shape_kind, :points, :bounds, :segments, keyword_init: true)

        def self.flatten(commands, preserve_initial_line: false)
          new.flatten(commands, preserve_initial_line: preserve_initial_line)
        end

        def flatten(commands, preserve_initial_line: false)
          pen = PenState.new
          subpaths = []
          segments = []
          commands.each do |command|
            letter = command.letter.upcase
            if letter == "M" && segments.any?
              subpaths << build_result(segments)
              segments = []
            end
            if segments.empty? && letter != "M" && !(preserve_initial_line && subpaths.empty? && letter == "L")
              segments << ["M", [pen.current.dup]]
            end
            if letter == "A"
              segments.concat(resolve_arc(pen, command))
              next
            end
            points = resolve_command(pen, command)
            segments << [letter, points] if points
            next unless letter == "Z"

            pen.close_to(segments.first.last.first)
            subpaths << build_result(segments)
            segments = []
          end
          subpaths << build_result(segments) unless segments.empty?
          subpaths
        end

        private

        def resolve_arc(pen, command)
          arc_segments = EllipticalArc.to_cubics(pen.current, command.args, absolute: command.absolute?)
          pen.set_current(command.args.last(2), absolute: command.absolute?)
          arc_segments.map { |kind, points| [kind == :line ? "L" : "C", points] }
        end

        def resolve_command(pen, command)
          case command.letter.upcase
          when "M", "L" then pen.line_to(command, absolute: command.absolute?)
          when "H" then pen.h_line_to(command, absolute: command.absolute?)
          when "V" then pen.v_line_to(command, absolute: command.absolute?)
          when "C"
            pen.cubic_to(command, absolute: command.absolute?)
            return pen.flush_curve_points
          when "Z" then return []
          else return nil
          end
          [pen.current.dup]
        end

        def build_result(segments)
          points = segments.flat_map(&:last)
          letters = segments.map(&:first)
          kind = if letters.include?("C")
                   (letters - %w[M C]).empty? ? :polybezier : :path
                 else
                   letters.last == "Z" ? :polygon : :polyline
                 end
          Result.new(shape_kind: kind, points: points, bounds: bounds_for(points), segments: segments)
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

      # Tracks current position and pending bezier control points while
      # flattening a path. Single-use per flatten() call.
      class PenState
        attr_reader :current, :pending_curve_points

        def initialize
          @current = [0.0, 0.0]
          @pending_curve_points = []
        end

        def close_to(point)
          @current = point.dup
        end

        def set_current(point, absolute:)
          @current = absolute ? point.dup : @current.zip(point).map { |origin, delta| origin + delta }
        end

        def line_to(command, absolute:)
          x, y = command.args
          @current = absolute ? [x, y] : [@current[0] + x, @current[1] + y]
        end

        def h_line_to(command, absolute:)
          x, = command.args
          @current = if absolute
                       [x, @current[1]]
                     else
                       [@current[0] + x, @current[1]]
                     end
        end

        def v_line_to(command, absolute:)
          y, = command.args
          @current = if absolute
                       [@current[0], y]
                     else
                       [@current[0], @current[1] + y]
                     end
        end

        def cubic_to(command, absolute:)
          x1, y1, x2, y2, x, y = command.args
          if absolute
            @pending_curve_points = [[x1, y1], [x2, y2], [x, y]]
            @current = [x, y]
          else
            @pending_curve_points = [
              [@current[0] + x1, @current[1] + y1],
              [@current[0] + x2, @current[1] + y2],
              [@current[0] + x, @current[1] + y]
            ]
            @current = @current.zip([x, y]).map { |a, b| a + b }
          end
        end

        def flush_curve_points
          pts = @pending_curve_points
          @pending_curve_points = []
          pts
        end
      end
    end
  end
end
