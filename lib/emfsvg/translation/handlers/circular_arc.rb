# frozen_string_literal: true

module Emfsvg
  module Translation
    module Handlers
      # Recover only circles whose integer radial points reproduce the source.
      # Native Arc/Chord/Pie do not update the current point; SVG closure does.
      class CircularArc
        include Emf::Emr::Binary::TypeCodes

        def self.from_commands(commands, kind: :arc)
          return unless supported_commands?(commands, kind)

          prefix, start, args = commands.first(3).map(&:args)
          radius, ry, rotation, large, sweep, x, y = args
          return unless radius.positive? && radius == ry && radius == radius.round
          return unless rotation.zero? && large == sweep && [0, 1].include?(sweep)

          finish = [x, y]
          center = circle_center(start, finish, radius)
          return unless valid_center?(center, commands, kind)

          radials = [start, finish].map { |point| point.zip(center).map { |value, origin| (value - origin).round } }
          return unless [start, finish].zip(radials).all? do |point, radial|
            projects_to?(point, radial, center, radius)
          end

          new(prefix, kind == :arc ? finish : start, center, radius, radials, sweep, kind)
        end

        def self.valid_center?(center, commands, kind)
          center && (kind != :pie || commands[3].args == center)
        end
        private_class_method :valid_center?

        def self.supported_commands?(commands, kind)
          letters = { arc: %w[M M A], chord: %w[M M A Z], pie: %w[M M A L Z] }
          letters.key?(kind) && commands.map(&:letter) == letters[kind]
        end
        private_class_method :supported_commands?

        def self.circle_center(start, finish, radius)
          x, y = finish
          dx, dy = finish.zip(start).map { |a, b| a - b }
          distance = Math.hypot(dx, dy)
          return unless distance.positive? && distance <= 2 * radius

          height = Math.sqrt([(radius**2) - ((distance**2) / 4), 0].max)
          center = [((start[0] + x) / 2) + ((dy * height) / distance),
                    ((start[1] + y) / 2) - ((dx * height) / distance)]
          center.map(&:round) if center.all? { |value| (value - value.round).abs < 0.001 }
        end
        private_class_method :circle_center

        def self.projects_to?(point, radial, center, radius)
          length = Math.hypot(*radial)
          length.positive? && point.zip(center, radial).all? do |value, origin, delta|
            format("%.4f", value) == format("%.4f", origin + ((radius * delta) / length))
          end
        end
        private_class_method :projects_to?

        def initialize(prefix, finish, center, radius, radials, sweep, kind)
          @prefix = prefix
          @finish = finish
          @center = center
          @radius = radius
          @radials = radials
          @sweep = sweep
          @kind = kind
        end

        def safe_for?(context)
          x, y = @center
          [x - @radius, y - @radius, x + @radius, y + @radius].all? do |value|
            (-(2**31)..((2**31) - 1)).cover?((value * context.scaler.factor).round)
          end
        end

        def emit(context)
          records = Emf::Emr::Binary::Records
          move(context, @prefix)
          context.emit(records::SetArcDirection, i_type: SETARCDIRECTION, arc_direction: @sweep.zero? ? 1 : 2)
          x, y = @center
          points = @radials.map { |radial| radial.zip(@center).map { |delta, origin| delta + origin } }
          record, type = { arc: [records::Arc, ARC], chord: [records::Chord, CHORD],
                           pie: [records::Pie, PIE] }.fetch(@kind)
          context.emit(record, i_type: type,
                               rcl_box: context.rect_attrs(x - @radius, y - @radius, x + @radius, y + @radius),
                               ptl_start: context.point_attrs(*points[0]),
                               ptl_end: context.point_attrs(*points[1]))
          move(context, @finish)
        end

        private

        def move(context, point)
          context.emit(Emf::Emr::Binary::Records::MoveToEx, i_type: MOVETOEX, origin: context.point_attrs(*point))
        end
      end
    end
  end
end
