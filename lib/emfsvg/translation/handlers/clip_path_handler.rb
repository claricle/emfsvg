# frozen_string_literal: true

module Emfsvg
  module Translation
    module Handlers
      # <clipPath> defines a clipping region referenced by id. Like
      # <defs>, its children must NOT be emitted as drawing records —
      # the clip is rendered only when referenced via clip-path=.
      class ClipPathHandler
        def self.call(_element, _context)
          # Intentional no-op.
        end
      end
    end
  end
end
