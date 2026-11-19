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
          pattern = element.selected_pattern || element.unused_pattern
          emit_pattern(pattern, context) if pattern
          element.children.each do |child|
            next unless child.is_a?(Svg::Elements::Pattern)

            register_pattern_brush(child, context)
          end
          registry = context.clip_path_registry
          return unless registry

          element.children.each do |child|
            next unless child.is_a?(Svg::Elements::ClipPath)
            next if context.preserve_selected_clip(child)
            next if context.preserve_unused_selected_clip(child)
            next if registry.referenced?(child.id)
            next unless child.unused_rectangle_bounds

            context.emit_unused_clip_rectangle(child.unused_rectangle_bounds)
          end
        end

        # General (non-canonical) <pattern> definitions from arbitrary
        # SVG authors (e.g. Visio exports): a raster tile referenced by
        # fill="url(#id)". The declared SVG width/height live in tile
        # units, not bitmap pixels, so unlike #emit_pattern the DIB is
        # built from the decoded bitmap's own dimensions.
        def self.register_pattern_brush(pattern, context)
          return unless pattern.id && pattern.image&.data_uri?
          return unless pattern.image.mime_type == "image/png"
          return if context.pattern_handles.key?(pattern.id)

          decoded = PngDecoder.decode(pattern.image.decoded_bytes)
          return unless decoded

          dib = DibEncoder.encode(decoded.width, decoded.height, decoded.pixels)
          return if dib.empty?

          handle = context.allocate_handle
          context.emit(Emf::Emr::Binary::Records::CreateDibPatternBrushPt,
                       i_type: Emf::Emr::Binary::TypeCodes::CREATEDIBPATTERNBRUSHPT,
                       ih_brush: handle, i_usage: 0,
                       off_bmi: 32, cb_bmi: 40, off_bits: 72, cb_bits: dib.bytesize - 40,
                       body: dib)
          context.pattern_handles[pattern.id] = handle
        end
        private_class_method :register_pattern_brush

        def self.emit_pattern(pattern, context)
          image = pattern.image
          decoded = PngDecoder.decode(image.decoded_bytes)
          return unless decoded && decoded.width == image.width && decoded.height == image.height

          dib = DibEncoder.encode(decoded.width, decoded.height, decoded.pixels)
          handle = context.allocate_handle
          context.emit(Emf::Emr::Binary::Records::CreateDibPatternBrushPt,
                       i_type: Emf::Emr::Binary::TypeCodes::CREATEDIBPATTERNBRUSHPT,
                       ih_brush: handle, i_usage: 0,
                       off_bmi: 32, cb_bmi: 40, off_bits: 72, cb_bits: dib.bytesize - 40,
                       body: dib)
          context.pattern_handles[pattern.id] = handle
        end
        private_class_method :emit_pattern
      end
    end
  end
end
