# frozen_string_literal: true

module Emfsvg
  module Translation
    # A complete absolute line can use a temporary integer device origin when
    # its fixed-scale coordinates overflow. Restrict this to independent draws:
    # pending paths, relative commands and clips carry additional state.
    module LocalOrigin
      module_function

      def for_path(element, scaler)
        return unless scaler.scaled? && independent_line?(element)

        points = element.commands.map(&:args)
        return unless finite_points?(points)
        return unless points.flatten.any? { |value| scaler.unsafe?(value) }

        origin = points.transpose.map do |values|
          values.any? { |value| scaler.unsafe?(value) } ? ((values.min + values.max) / 2.0).floor : 0
        end
        return unless origin.all? { |value| Scaler::Fixed::INT32_RANGE.cover?(value) }
        return unless points.all? { |point| point.zip(origin).all? { |value, offset| !scaler.unsafe?(value - offset) } }

        origin
      end

      def independent_line?(element)
        element.is_a?(Svg::Elements::Path) && element.children.empty? &&
          !element.clip_path && element.fill.null? && element.path_record_kind.nil? &&
          [nil, :polyline].include?(element.line_record_kind) && element.commands.map(&:letter) == %w[M L]
      end

      def finite_points?(points)
        points.all? do |point|
          point.size == 2 && point.all? { |value| value.is_a?(Numeric) && value.finite? }
        end
      end
    end
  end
end
