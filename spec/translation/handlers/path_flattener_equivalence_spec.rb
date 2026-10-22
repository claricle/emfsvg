# frozen_string_literal: true

require "spec_helper"

module PreviousFlattening
  # Verbatim copy of the previous flattener (with its pen state).
  class PreviousPathFlattener
    Result = Struct.new(:shape_kind, :points, :bounds, keyword_init: true)

    def self.flatten(commands)
      new.flatten(commands)
    end

    def flatten(commands)
      pen = PreviousPenState.new
      closed = false
      has_curve = false
      points = []

      commands.each do |command|
        case command.letter.upcase
        when "M"
          pen.move_to(command, absolute: command.absolute?)
          points << pen.current.dup
        when "L"
          pen.line_to(command, absolute: command.absolute?)
          points << pen.current.dup
        when "H"
          pen.h_line_to(command, absolute: command.absolute?)
          points << pen.current.dup
        when "V"
          pen.v_line_to(command, absolute: command.absolute?)
          points << pen.current.dup
        when "C"
          has_curve = true
          pen.cubic_to(command, absolute: command.absolute?)
          points.concat(pen.flush_curve_points)
        when "Z"
          closed = true
        end
      end

      Result.new(
        shape_kind: shape_kind(closed, has_curve),
        points: points,
        bounds: bounds_for(points)
      )
    end

    private

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

      xs = points.map { |x, _| x }
      ys = points.map { |_, y| y }
      Bounds.new(left: xs.min, top: ys.min, right: xs.max, bottom: ys.max)
    end
  end

  # Tracks current position and pending bezier control points while
  # flattening a path. Single-use per flatten() call.
  class PreviousPenState
    attr_reader :current, :pending_curve_points

    def initialize
      @current = [0.0, 0.0]
      @pending_curve_points = []
    end

    def move_to(command, absolute:)
      x, y = command.args
      @current = absolute ? [x, y] : [@current[0] + x, @current[1] + y]
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

# The flattener was changed to allocate less (no point copies, no upcased
# letters). This pins it to the previous implementation over random command
# lists of every kind, absolute and relative.
RSpec.describe Emfsvg::Translation::Handlers::PathFlattener do
  def command(letter, random)
    count = Emfsvg::Svg::PathData::ARG_COUNTS.fetch(letter.upcase)
    args = Array.new(count) { (random.rand - 0.5) * 2000.0 }
    Emfsvg::Svg::PathData::Command.new(letter: letter, args: args)
  end

  def snapshot(result)
    [result.shape_kind, result.points, result.bounds.to_a]
  end

  it "flattens exactly as the previous implementation did" do
    random = Random.new(20_261_022)
    letters = %w[M m L l H h V v C c Z z S Q T A]
    300.times do
      commands = Array.new(random.rand(0..12)) { command(letters[random.rand(letters.size)], random) }
      expected = PreviousFlattening::PreviousPathFlattener.flatten(commands)
      expect(snapshot(described_class.flatten(commands))).to eq(snapshot(expected)), commands.inspect
    end
  end
end
