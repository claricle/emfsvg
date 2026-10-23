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
          emit_unused_pattern(element.unused_pattern, context) if element.unused_pattern
          registry = context.clip_path_registry
          return unless registry

          element.children.each do |child|
            next unless child.is_a?(Svg::Elements::ClipPath)
            next if context.preserve_selected_clip(child)
            next if registry.referenced?(child.id)
            next unless child.unused_rectangle_bounds

            context.emit_unused_clip_rectangle(child.unused_rectangle_bounds)
          end
        end

        def self.emit_unused_pattern(pattern, context)
          image = pattern.image
          decoded = PngDecoder.decode(image.decoded_bytes)
          return unless decoded && decoded.width == image.width && decoded.height == image.height

          dib = DibEncoder.encode(decoded.width, decoded.height, decoded.pixels)
          context.emit(Emf::Emr::Binary::Records::CreateDibPatternBrushPt,
                       i_type: Emf::Emr::Binary::TypeCodes::CREATEDIBPATTERNBRUSHPT,
                       ih_brush: context.allocate_handle, i_usage: 0,
                       off_bmi: 32, cb_bmi: 40, off_bits: 72, cb_bits: dib.bytesize - 40,
                       body: dib)
        end
        private_class_method :emit_unused_pattern
      end
    end
  end
end
