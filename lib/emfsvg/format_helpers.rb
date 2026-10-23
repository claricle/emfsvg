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

    # Digit strings shared by every formatted number. Filled on first use so
    # a render only pays for the digit groups it actually emits.
    INTEGER_DIGITS = Hash.new { |cache, key| cache[key] = key.to_s.freeze }
    FRACTION_DIGITS = Hash.new { |cache, key| cache[key] = format("%04d", key).freeze }
    INTEGER_CACHE_LIMIT = 10_000
    private_constant :INTEGER_DIGITS, :FRACTION_DIGITS, :INTEGER_CACHE_LIMIT

    # Format a single float as "%.4f" with C printf semantics.
    def fmt(n)
      append(+"", n)
    end

    # Append the "%.4f" text of +n+ to +buffer+ and return the buffer.
    # Byte-identical to +fmt+; skips the intermediate string per number.
    def append(buffer, n)
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
          whole = units / 10_000
          buffer << "-" if f.negative?
          buffer << (whole < INTEGER_CACHE_LIMIT ? INTEGER_DIGITS[whole] : whole.to_s)
          buffer << "." << FRACTION_DIGITS[units % 10_000]
          return buffer
        end
      end

      buffer << fmt_via_decimal(f)
    end

    def fmt_via_decimal(value)
      bd = BigDecimal(format("%.20f", value))
      format("%.4f", bd.round(4, half: :even).to_f)
    end

    # Format a coordinate pair as "X,Y " (trailing space, matching
    # libemf2svg's point_draw output).
    def fmt_xy(x, y)
      append_xy(+"", x, y)
    end

    # Append "X,Y " to +buffer+ and return the buffer.
    def append_xy(buffer, x, y)
      append(buffer, x)
      buffer << ","
      append(buffer, y)
      buffer << " "
    end
  end
end
