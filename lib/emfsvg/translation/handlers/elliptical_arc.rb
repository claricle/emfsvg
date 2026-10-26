# frozen_string_literal: true

module Emfsvg
  module Translation
    module Handlers
      # Converts SVG endpoint-form elliptical arcs into cubic Beziers.
      class EllipticalArc
        def self.to_cubics(start, args, absolute:)
          finish = endpoint(start, args, absolute)
          return [] if start == finish

          rx, ry, rotation, large_arc, sweep = args
          return [[:line, [finish]]] if rx.zero? || ry.zero?

          geometry = ellipse_geometry(start, finish, rx.abs, ry.abs, rotation, large_arc, sweep)
          cubic_segments(geometry, finish)
        end

        def self.endpoint(start, args, absolute)
          x, y = args.last(2)
          absolute ? [x, y] : [start[0] + x, start[1] + y]
        end
        private_class_method :endpoint

        def self.ellipse_geometry(start, finish, rx, ry, rotation, large_arc, sweep)
          phi = rotation * Math::PI / 180.0
          cos_phi = Math.cos(phi)
          sin_phi = Math.sin(phi)
          dx = (start[0] - finish[0]) / 2.0
          dy = (start[1] - finish[1]) / 2.0
          x1 = (cos_phi * dx) + (sin_phi * dy)
          y1 = (-sin_phi * dx) + (cos_phi * dy)
          lambda = ((x1**2) / (rx**2)) + ((y1**2) / (ry**2))
          if lambda > 1
            factor = Math.sqrt(lambda)
            rx *= factor
            ry *= factor
          end

          cx1, cy1 = center_offset(rx, ry, x1, y1, large_arc, sweep)
          center = center_point(start, finish, cx1, cy1, cos_phi, sin_phi)
          theta, delta = arc_angles(rx, ry, x1, y1, cx1, cy1, large_arc, sweep)
          { center: center, rx: rx, ry: ry, cos_phi: cos_phi, sin_phi: sin_phi, theta: theta, delta: delta }
        end
        private_class_method :ellipse_geometry

        def self.center_offset(rx, ry, x1, y1, large_arc, sweep)
          numerator = [((rx**2) * (ry**2)) - ((rx**2) * (y1**2)) - ((ry**2) * (x1**2)), 0].max
          denominator = ((rx**2) * (y1**2)) + ((ry**2) * (x1**2))
          factor = denominator.zero? ? 0.0 : Math.sqrt(numerator / denominator)
          factor *= -1 if large_arc == sweep
          [factor * rx * y1 / ry, -factor * ry * x1 / rx]
        end
        private_class_method :center_offset

        def self.center_point(start, finish, cx1, cy1, cos_phi, sin_phi)
          [
            (cos_phi * cx1) - (sin_phi * cy1) + ((start[0] + finish[0]) / 2.0),
            (sin_phi * cx1) + (cos_phi * cy1) + ((start[1] + finish[1]) / 2.0)
          ]
        end
        private_class_method :center_point

        def self.arc_angles(rx, ry, x1, y1, cx1, cy1, large_arc, sweep)
          ux = (x1 - cx1) / rx
          uy = (y1 - cy1) / ry
          vx = (-x1 - cx1) / rx
          vy = (-y1 - cy1) / ry
          theta = Math.atan2(uy, ux)
          delta = Math.atan2((ux * vy) - (uy * vx), (ux * vx) + (uy * vy))
          delta -= 2 * Math::PI if sweep.zero? && delta.positive?
          delta += 2 * Math::PI if sweep != 0 && delta.negative?
          delta += (sweep.zero? ? -2 : 2) * Math::PI if large_arc != 0 && delta.abs < Math::PI
          delta += (sweep.zero? ? 2 : -2) * Math::PI if large_arc.zero? && delta.abs > Math::PI
          [theta, delta]
        end
        private_class_method :arc_angles

        def self.cubic_segments(geometry, finish)
          center = geometry.fetch(:center)
          rx = geometry.fetch(:rx)
          ry = geometry.fetch(:ry)
          cos_phi = geometry.fetch(:cos_phi)
          sin_phi = geometry.fetch(:sin_phi)
          theta = geometry.fetch(:theta)
          delta = geometry.fetch(:delta)
          count = (delta.abs / (Math::PI / 2)).ceil
          step = delta / count
          Array.new(count) do |index|
            a = theta + (index * step)
            b = a + step
            alpha = (4.0 / 3.0) * Math.tan((b - a) / 4.0)
            point_a, derivative_a = point_and_derivative(center, rx, ry, cos_phi, sin_phi, a)
            point_b, derivative_b = point_and_derivative(center, rx, ry, cos_phi, sin_phi, b)
            point_b = finish if index == count - 1
            [
              :cubic,
              [
                [point_a[0] + (alpha * derivative_a[0]), point_a[1] + (alpha * derivative_a[1])],
                [point_b[0] - (alpha * derivative_b[0]), point_b[1] - (alpha * derivative_b[1])],
                point_b
              ]
            ]
          end
        end
        private_class_method :cubic_segments

        def self.point_and_derivative(center, rx, ry, cos_phi, sin_phi, angle)
          cos_angle = Math.cos(angle)
          sin_angle = Math.sin(angle)
          point = [
            center[0] + (rx * cos_phi * cos_angle) - (ry * sin_phi * sin_angle),
            center[1] + (rx * sin_phi * cos_angle) + (ry * cos_phi * sin_angle)
          ]
          derivative = [
            (-rx * cos_phi * sin_angle) - (ry * sin_phi * cos_angle),
            (-rx * sin_phi * sin_angle) + (ry * cos_phi * cos_angle)
          ]
          [point, derivative]
        end
        private_class_method :point_and_derivative
      end
    end
  end
end
