# frozen_string_literal: true

module Emfsvg
  module Translation
    module Handlers
      # C's Pie formatter maps radii as points, adding the viewport origin.
      # Recover that origin only when an integer circle reproduces every byte.
      class MappedPie < MappedCircularArc
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
      end
    end
  end
end
