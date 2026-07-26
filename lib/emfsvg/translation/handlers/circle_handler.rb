# frozen_string_literal: true

require "emf"

module Emfsvg
  module Translation
    module Handlers
      # <circle> is normalized to <ellipse> before reaching the handler
      # — it dispatches to EllipseHandler.
      class CircleHandler
        def self.call(element, context)
          EllipseHandler.call(element.to_ellipse, context)
        end
      end
    end
  end
end
