# frozen_string_literal: true

module Emfsvg
  module Svg
    module PathData
      # One parsed SVG path command (e.g. "M 1 2" or "L 3 4").
      # `letter` preserves case (absolute uppercase vs relative lowercase).
      Command = Struct.new(:letter, :args, keyword_init: true) do
        def absolute?
          ARG_COUNTS.key?(letter) || (!LETTER_ARG_COUNTS.key?(letter) && letter == letter.upcase)
        end
      end
    end
  end
end
