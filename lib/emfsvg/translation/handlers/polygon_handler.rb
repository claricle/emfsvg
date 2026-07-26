# frozen_string_literal: true

require "emf"

module Emfsvg
  module Translation
    module Handlers
      # <polygon> uses the same body as <polyline> but emits POLYGON
      # (closed). Reuses PolylineHandler internals.
      class PolygonHandler < PolylineHandler
        def self.call(element, context)
          new.translate(element, context)
        end
      end
    end
  end
end
