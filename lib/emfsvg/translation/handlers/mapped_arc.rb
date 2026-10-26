# frozen_string_literal: true

module Emfsvg
  module Translation
    module Handlers
      # Recover mapped near-semicircles only when integer centers reproduce both endpoints.
      class MappedArc < MappedCircularArc
        def self.from_commands(commands, scaler:)
          return unless scaler.scaled? && commands.map(&:letter) == %w[M M A]

          prefix, start, args = commands.map(&:args)
          rx, ry, rotation, large, sweep, x, y = args
          return unless rotation.zero? && large == sweep && [0, 1].include?(sweep)

          finish = [x, y]
          midpoint = start.zip(finish).map { |a, b| ((a + b) / 2).round }
          [-1, 0, 1].repeated_permutation(2) do |offsets|
            center = midpoint.zip(offsets).map { |value, offset| value + offset }
            radius = Math.hypot(start[0] - center[0], start[1] - center[1]).round
            next unless radius.positive?

            origin = mapping_origin(rx, ry, radius)
            next unless origin

            radials = [start, finish].map { |point| recover_radial(point, center, radius, origin, scaler.factor) }
            next if radials.any?(&:nil?)

            return new(prefix, finish, center, radius, radials, sweep, :arc, origin: origin)
          end
          nil
        end

        def self.mapping_origin(rx, ry, radius)
          origin = [rx - radius, ry - radius]
          origin if origin.all? { |value| value == value.round && Scaler::Fixed::INT32_RANGE.cover?(value) }
        end
        private_class_method :mapping_origin
      end
    end
  end
end
