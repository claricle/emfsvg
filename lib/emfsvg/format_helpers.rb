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
      bd = BigDecimal(format("%.20f", n.to_f))
      format("%.4f", bd.round(4, half: :even).to_f)
    end

    # Format a coordinate pair as "X,Y " (trailing space, matching
    # libemf2svg's point_draw output).
    def fmt_xy(x, y)
      "#{fmt(x)},#{fmt(y)} "
    end
  end
end
