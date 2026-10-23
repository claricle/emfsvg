# frozen_string_literal: true

require "bigdecimal"

module Emfsvg
  # C-printf-compatible float formatting. libemf2svg uses C's printf with
  # the platform's default rounding (round-half-to-even on the actual
  # IEEE-754 double bits). Ruby's Float#round and format("%.4f", v) both
  # lose precision for values landing near the 4-decimal midpoint because
  # they operate on the display value rather than the true bits.
  #
  # Example: 459.04375 stored as 459.04374999… → C: "459.0437",
  # Ruby format: "459.0438". We expose the actual bits via "%.20f"
  # then round via BigDecimal for exact IEEE-754 semantics.
  module FormatHelpers
    module_function

    # Format a single float as "%.4f" with C printf semantics.
    def fmt(n)
      f = n.to_f
      scaled = f.abs * 10_000.0
      # Fast path: when the scaled value is clearly away from a rounding
      # tie, double rounding error (< 1e-7 below 1e9) cannot change which
      # way it rounds, so plain integer rounding matches the exact
      # half-even result. Ties, zero, NaN and huge values take the exact path.
      if f != 0.0 && scaled < 1e9
        floor = scaled.floor
        frac = scaled - floor
        if (frac - 0.5).abs > 1e-6
          units = frac > 0.5 ? floor + 1 : floor
          sign = f.negative? ? "-" : ""
          return format("%<sign>s%<int>d.%<dec>04d", sign: sign, int: units / 10_000, dec: units % 10_000)
        end
      end

      fmt_via_decimal(f)
    end

    def fmt_via_decimal(value)
      bd = BigDecimal(format("%.20f", value))
      format("%.4f", bd.round(4, half: :even).to_f)
    end

    # Format a coordinate pair as "X,Y " (trailing space, matching
    # libemf2svg's point_draw output).
    def fmt_xy(x, y)
      "#{fmt(x)},#{fmt(y)} "
    end
  end
end
