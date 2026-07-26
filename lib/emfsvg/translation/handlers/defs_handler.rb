# frozen_string_literal: true

module Emfsvg
  module Translation
    module Handlers
      # <defs> contains reusable resources (clipPath, pattern, image)
      # that are referenced by id from elsewhere in the document. The
      # contents must NOT be emitted as drawing records — they are
      # rendered only when referenced.
      class DefsHandler
        def self.call(_element, _context)
          # Intentional no-op: do not descend into <defs> children.
        end
      end
    end
  end
end
