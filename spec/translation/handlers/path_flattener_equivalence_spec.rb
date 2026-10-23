# frozen_string_literal: true

require "spec_helper"

module PreviousFlattening
  module Translation
    module Handlers
      # Resolve supported commands to absolute points without joining figures.
      # Arc/quadratic commands remain unsupported.
      class PathFlattener
        Result = Struct.new(:shape_kind, :points, :bounds, :segments, keyword_init: true)

        def self.flatten(commands)
          new.flatten(commands)
        end

        def flatten(commands)
          pen = PenState.new
          subpaths = []
          segments = []
          commands.each do |command|
            letter = command.letter.upcase
            if letter == "M" && segments.any?
              subpaths << build_result(segments)
              segments = []
            end
            segments << ["M", [pen.current.dup]] if segments.empty? && letter != "M"
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

          xs = points.map { |x, _| x }
          ys = points.map { |_, y| y }
          Bounds.new(left: xs.min, top: ys.min, right: xs.max, bottom: ys.max)
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

RSpec.describe Emfsvg::Translation::Handlers::PathFlattener do
  let(:command) do
    lambda do |letter, random|
      count = Emfsvg::Svg::PathData::ARG_COUNTS.fetch(letter.upcase)
      args = Array.new(count) { (random.rand - 0.5) * 2000.0 }
      Emfsvg::Svg::PathData::Command.new(letter: letter, args: args)
    end
  end

  let(:snapshot) do
    ->(results) { results.map { |result| [result.shape_kind, result.points, result.bounds.to_a, result.segments] } }
  end

  it "flattens exactly as the previous implementation did" do
    random = Random.new(20_261_022)
    letters = %w[M m L l H h V v C c Z z S Q T A]
    300.times do
      commands = Array.new(random.rand(0..12)) { command.call(letters[random.rand(letters.size)], random) }
      expected = PreviousFlattening::Translation::Handlers::PathFlattener.flatten(commands)
      expect(snapshot.call(described_class.flatten(commands))).to eq(snapshot.call(expected)), commands.inspect
    end
  end
end
