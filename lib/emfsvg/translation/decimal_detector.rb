# frozen_string_literal: true

module Emfsvg
  module Translation
    # Walks an Svg::Document tree to decide whether any coordinate
    # attribute has a non-integer value. If yes, the renderer installs
    # `Scaler::Fixed` and emits MapMode scaling records so the
    # decimals survive the int32 truncation in EMF.
    #
    # Also detects overflow: if any decimal coord is so large that
    # scaling would overflow int32, the renderer falls back to
    # Identity (accepting the truncation for that fixture).
    module DecimalDetector
      module_function

      def needs_scaling?(document)
        any_decimal?(document.root_element)
      end

      def safe_for_fixed_scale?(document, scaler)
        !any_unsafe?(document.root_element, scaler)
      end

      # ---- private ----

      def any_decimal?(element)
        return false unless element

        return true if explicit_cosmetic_pixel_stroke?(element)

        element_attrs = decimal_attrs_for(element)
        return true if element_attrs.any? { |attr| decimal?(element.send(attr)) }

        path = path_commands(element)
        return true if path&.any? { |cmd| decimal?(cmd.args) }

        element.children.any? { |c| any_decimal?(c) }
      end

      def any_unsafe?(element, scaler)
        return false unless element

        element_attrs = decimal_attrs_for(element)
        return true if element_attrs.any? { |attr| unsafe_value?(element.send(attr), scaler) }

        path = path_commands(element)
        return true if path&.any? { |cmd| cmd.args.any? { |a| scaler.unsafe?(a) } }

        element.children.any? { |c| any_unsafe?(c, scaler) }
      end

      # The EMF renderer preserves a cosmetic 1px width only when the
      # translator uses a map scale. Explicit cap/join attributes
      # distinguish real pens from the renderer's NULL-pen fallback.
      def explicit_cosmetic_pixel_stroke?(element)
        stroke = element.stroke if element.respond_to?(:stroke)
        stroke && stroke.raw_width == "1px" &&
          (stroke.line_cap_explicit || stroke.line_join_explicit) &&
          !stroke.paint.null?
      end

      # Coordinate-bearing attributes per element class. Returns [] for
      # elements with no coords (Group, Defs, etc).
      def decimal_attrs_for(element)
        case element
        when Svg::Elements::Rect then %i[x y width height rx ry]
        when Svg::Elements::Ellipse then %i[cx cy rx ry]
        when Svg::Elements::Circle then %i[cx cy r]
        when Svg::Elements::Line then %i[x1 y1 x2 y2]
        when Svg::Elements::Polyline, Svg::Elements::Polygon then [:points]
        when Svg::Elements::Path then [:commands]
        when Svg::Elements::Text then %i[x y font_size]
        when Svg::Elements::Image then %i[x y width height]
        else []
        end
      end

      def path_commands(element)
        return nil unless element.is_a?(Svg::Elements::Path)

        element.commands
      end

      # `value` may be: Float, Integer, Array of [x,y] pairs, Array of
      # PathData::Command, or nil.
      def decimal?(value)
        return false if value.nil?

        case value
        when Float then !value.finite? || (value != value.to_i)
        when Array
          value.any? { |v| decimal?(v) }
        when Svg::PathData::Command then decimal?(value.args)
        when String then value.match?(/\.\d/)
        else false
        end
      end

      # Former name, kept so existing callers keep working.
      alias has_decimal? decimal?
      module_function :has_decimal?

      def pair_or_command?(value)
        value.is_a?(Array) || value.is_a?(Svg::PathData::Command)
      end

      def unsafe_value?(value, scaler)
        return false if value.nil?

        case value
        when Numeric then scaler.unsafe?(value)
        when Array then value.any? { |v| unsafe_value?(v, scaler) }
        when Svg::PathData::Command then unsafe_value?(value.args, scaler)
        when String then extract_floats(value).any? { |f| scaler.unsafe?(f) }
        else false
        end
      end

      def path_unsafe?(path_str, scaler)
        extract_floats(path_str).any? { |f| scaler.unsafe?(f) }
      end

      def extract_floats(str)
        str.to_s.scan(/-?\d+(?:\.\d+)?/).map(&:to_f)
      end
    end
  end
end
