# frozen_string_literal: true

module Emfsvg
  module Translation
    module Handlers
      # <defs> contains reusable resources (clipPath, pattern, image)
      # that are referenced by id from elsewhere in the document. The
      # contents are never emitted as drawings. Unused canonical clipping
      # records can be preserved without applying a clip to later drawings.
      class DefsHandler
        def self.call(element, context)
          registry = context.clip_path_registry
          return unless registry

          element.children.each do |child|
            next unless child.is_a?(Svg::Elements::ClipPath)
            next if registry.referenced?(child.id)
            next unless child.unused_rectangle_bounds

            context.emit_unused_clip_rectangle(child.unused_rectangle_bounds)
          end
        end
      end
    end
  end
end
