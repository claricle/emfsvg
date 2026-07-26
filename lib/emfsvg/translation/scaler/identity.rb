# frozen_string_literal: true

module Emfsvg
  module Translation
    module Scaler
      # Default scaler: truncates SVG decimal coords to int32 1:1.
      # Matches MM_TEXT map mode (no scaling records emitted).
      class Identity
        def to_int(decimal)
          decimal.to_i
        end

        def factor
          1
        end

        def scaled?
          false
        end
      end
    end
  end
end
