# frozen_string_literal: true

module Emfsvg
  module Translation
    module Scaler
      # Fixed-factor scaler: multiplies SVG decimal coords by
      # `FACTOR` (default 10_000) so 4 decimal places are preserved
      # as integer fractions in EMF int32 fields. emfsvg's renderer
      # computes `sf_x = viewport_ext / window_ext = 1 / FACTOR` and
      # divides back to recover the decimal.
      #
      # Choice of 10_000 matches emfsvg's `%.4f` formatting exactly.
      # Larger factors risk int32 overflow on big coords (max safe
      # SVG coord ~ 214_000 with FACTOR=10_000).
      class Fixed
        class Overflow < RangeError; end

        INT32_RANGE = (-(2**31)..((2**31) - 1))
        FACTOR = 10_000
        MAX_SAFE_INPUT = 214_748 # ((2**31) - 1) / FACTOR, with margin

        attr_reader :factor

        def initialize(factor = FACTOR)
          @factor = factor
        end

        def to_int(decimal)
          raise Overflow, "coordinate exceeds scaled int32 range: #{decimal}" if unsafe?(decimal)

          (decimal.to_f * factor).round
        end

        def scaled?
          true
        end

        # True if `value` would overflow int32 when scaled. The
        # renderer falls back to Identity when ANY coord is unsafe.
        def unsafe?(value)
          scaled = value.to_f * factor
          !scaled.finite? || !INT32_RANGE.cover?(scaled.round)
        end
      end
    end
  end
end
