# frozen_string_literal: true

module Emfsvg
  module Translation
    module Handlers
      # C's Pie formatter maps radii as points, adding the viewport origin.
      # Recover that origin only when an integer circle reproduces every byte.
      class MappedPie < CircularArc
        def self.from_commands(commands, scaler:)
          return unless scaler.scaled? && commands.map(&:letter) == %w[M M A L Z]

          prefix, start, args, center = commands.first(4).map(&:args)
          rx, ry, rotation, large, sweep, x, y = args
          return unless rotation.zero? && large == sweep && [0, 1].include?(sweep)

          distance = Math.hypot(start[0] - center[0], start[1] - center[1])
          origin = [rx - distance, ry - distance].map(&:round)
          radius = rx - origin[0]
          return unless radius.positive? && (radius - (ry - origin[1])).abs < 0.00001
          return unless origin.all? { |value| Scaler::Fixed::INT32_RANGE.cover?(value) }

          radials = [start, [x, y]].map { |point| recover_radial(point, center, radius, origin, scaler.factor) }
          return if radials.any?(&:nil?)

          new(prefix, start, center, radius, radials, sweep, :pie, origin: origin)
        end

        def self.recover_radial(point, center, radius, origin, factor)
          logical_center = center.zip(origin).map { |value, offset| ((value - offset) * factor).round }
          logical_radius = (radius * factor).round
          # Four-decimal endpoints describe rounding intervals, not exact radial directions.
          # Try bounded directions inside those intervals while retaining int32 safety.
          [1, 10, 100].product([-0.000049, 0, 0.000049].repeated_permutation(2).to_a) do |multiple, offsets|
            radial = point.zip(center, offsets).map do |value, base, offset|
              ((value - base + offset) * factor * multiple).round
            end
            unless radial.zip(logical_center).all? { |delta, base| Scaler::Fixed::INT32_RANGE.cover?(delta + base) }
              next
            end

            length = Math.hypot(*radial)
            next if length.zero?

            projected = logical_center.zip(radial, origin).map do |base, delta, offset|
              ((base + ((logical_radius * delta) / length)) / factor) + offset
            end
            return radial.map { |value| value.to_f / factor } if point.zip(projected).all? do |expected, actual|
              format("%.4f", expected) == format("%.4f", actual)
            end
          end
          nil
        end
        private_class_method :recover_radial

        def initialize(*args, origin:)
          super(*args)
          @origin = origin
        end

        def safe_for?(context)
          points = [@prefix, @finish, *@radials.map { |radial| radial.zip(@center).map { |delta, base| delta + base } },
                    [@center[0] - @radius, @center[1] - @radius],
                    [@center[0] + @radius, @center[1] + @radius]]
          points.all? do |point|
            point.zip(@origin).all? { |value, offset| !context.scaler.unsafe?(value - offset) }
          end
        end

        def emit(context)
          context.with_local_origin(@origin) { super }
        end
      end
    end
  end
end
