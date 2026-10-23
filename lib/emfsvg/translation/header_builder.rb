# frozen_string_literal: true

require "emf"

module Emfsvg
  module Translation
    # Constructs Emf::Emr::Binary::Header values from a Svg::Document's
    # viewport. The header carries the bounds/frame rectangle, device
    # dimensions, and record counts that the EMF format requires.
    #
    # Round-trip contract: the bounds we emit must reproduce the input
    # SVG's viewport when emfsvg's EMF→SVG renderer reads it back.
    module HeaderBuilder
      DEFAULT_DPI = 96.0
      MM_PER_INCH = 25.4

      module_function

      def build(document, n_records:, n_handles:)
        bounds = bounds_for(document)
        frame = frame_for(bounds)
        Emf::Model::Emr::Header.new(
          bounds: bounds,
          frame: frame,
          signature: 0x464D4520, # " EMF"
          version: 0x00010000,
          n_bytes: 0, # filled in by serializer; placeholder
          n_records: n_records,
          n_handles: n_handles,
          s_reserved: 0,
          n_description: 0,
          off_description: 0,
          n_pal_entries: 0,
          device_pixels: device_pixels_for(document),
          device_mm: device_mm_for(document),
          cb_pixel_format: 0,
          off_pixel_format: 0,
          b_open_gl: 0,
          szl_micrometers: device_micrometers_for(document),
          n_size: 88
        )
      end

      def bounds_for(document)
        return legacy_bounds_for(document) if legacy_header?(document)

        min_x, min_y, w, h = document.bounds
        Emf::Model::Geometry::Rect.new(
          left: min_x.to_i,
          top: min_y.to_i,
          right: (min_x + w).to_i,
          bottom: (min_y + h).to_i
        )
      end

      # Legacy broken-Y header: the original signed bounds are not
      # recoverable, so emit the canonical equivalent [-1, -1, w-2, h-2],
      # which renders back to the same header and viewport. Only for
      # integral dimensions greater than 2; anything else keeps the
      # ordinary path.
      def legacy_header?(document)
        document.view_box.nil? &&
          document.legacy_broken_y_header? &&
          [document.width, document.height].all? { |d| (d % 1).zero? && d > 2 }
      end

      def legacy_bounds_for(document)
        Emf::Model::Geometry::Rect.new(
          left: -1, top: -1,
          right: document.width.to_i - 2, bottom: document.height.to_i - 2
        )
      end

      # Frame is the bounding rectangle in 0.01mm units. Computed from
      # bounds (pixels) using the document's effective DPI.
      def frame_for(bounds)
        units_per_pixel = (100.0 * MM_PER_INCH) / DEFAULT_DPI # 0.01mm per pixel
        Emf::Model::Geometry::Rect.new(
          left: (bounds.left * units_per_pixel).to_i,
          top: (bounds.top * units_per_pixel).to_i,
          right: (bounds.right * units_per_pixel).to_i,
          bottom: (bounds.bottom * units_per_pixel).to_i
        )
      end

      def device_pixels_for(document)
        Emf::Model::Geometry::Size.new(
          cx: document.width.to_i,
          cy: document.height.to_i
        )
      end

      def device_mm_for(document)
        px_per_mm = DEFAULT_DPI / MM_PER_INCH
        Emf::Model::Geometry::Size.new(
          cx: (document.width / px_per_mm).to_i,
          cy: (document.height / px_per_mm).to_i
        )
      end

      def device_micrometers_for(document)
        Emf::Model::Geometry::Size.new(
          cx: ((document.width / DEFAULT_DPI) * MM_PER_INCH * 1000).to_i,
          cy: ((document.height / DEFAULT_DPI) * MM_PER_INCH * 1000).to_i
        )
      end
    end
  end
end
