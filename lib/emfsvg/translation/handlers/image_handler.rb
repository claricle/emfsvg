# frozen_string_literal: true

require "emf"
require "base64"

module Emfsvg
  module Translation
    module Handlers
      # Translate <image href="data:image/png;base64,..."/> into
      # EMR_STRETCHDIBITS with an embedded DIB.
      #
      # v1 limitations:
      #   * PNG and JPEG data URIs only. Other formats fall through silently.
      #   * No aspect-ratio handling (uses width/height verbatim).
      class ImageHandler
        include SharedGdi
        include Emf::Emr::Binary::TypeCodes

        # Fixed portion of StretchDIBits record: 8 (emr) + 16 (bounds) +
        # 6*4 (int32 src/dest dims) + 6*4 (off/cb/i_usage/dw_rop/cx/cy)
        # = 80 bytes.
        STRETCHDIBITS_FIXED_SIZE = 80
        JPEG_TERMINAL_MARKERS = [0xDA, 0xD9].freeze
        JPEG_NON_FRAME_MARKERS = [0xC4, 0xC8, 0xCC].freeze

        def self.call(element, context)
          new.translate(element, context)
        end

        def translate(element, context)
          return unless element.data_uri?
          return unless %w[image/png image/jpeg image/jpg].include?(element.mime_type)

          dib = build_dib(element)
          return unless dib

          with_gdi_state(element, context) do
            emit_stretch_dibits(element, dib, context)
          end
        end

        private

        def build_dib(element)
          return build_jpeg_dib(element.decoded_bytes) if %w[image/jpeg image/jpg].include?(element.mime_type)

          png = element.decoded_bytes
          return nil unless png

          decoded = PngDecoder.decode(png)
          return nil unless decoded

          DibEncoder.encode(decoded.width, decoded.height, decoded.pixels)
        end

        # JPEG frame dimensions describe the embedded bitmap, independently of
        # the SVG destination size. Preserve its compressed bytes with BI_JPEG.
        def build_jpeg_dib(bytes)
          dimensions = jpeg_dimensions(bytes)
          return unless dimensions

          width, height = dimensions
          [40, width, height, 1, 0, 4, bytes.bytesize, 0, 0, 0, 0].pack("Vl<l<vvVVVVVV") + bytes
        end

        def jpeg_dimensions(bytes)
          return unless bytes&.start_with?("\xFF\xD8".b)

          offset = 2
          while offset + 4 <= bytes.bytesize
            return unless bytes.getbyte(offset) == 0xFF

            offset += 1 while bytes.getbyte(offset) == 0xFF
            marker = bytes.getbyte(offset)
            return if JPEG_TERMINAL_MARKERS.include?(marker)

            length = bytes.byteslice(offset + 1, 2)&.unpack1("n")
            return unless length && length >= 2 && offset + 1 + length <= bytes.bytesize

            if (0xC0..0xCF).cover?(marker) && !JPEG_NON_FRAME_MARKERS.include?(marker)
              return unless length >= 8

              height, width = bytes.byteslice(offset + 4, 4).unpack("nn")
              return [width, height] if width.positive? && height.positive?

              return
            end
            offset += 1 + length
          end
          nil
        end

        def emit_stretch_dibits(element, dib, context)
          bmi_size = 40
          bits_size = dib.bytesize - bmi_size
          off_bmi = STRETCHDIBITS_FIXED_SIZE
          off_bits = off_bmi + bmi_size

          bounds = context.rect_attrs(element.x, element.y,
                                      element.x + element.width,
                                      element.y + element.height)
          x_dest = context.scaler.to_int(element.x)
          y_dest = context.scaler.to_int(element.y)
          cx_dest = context.scaler.to_int(element.width)
          cy_dest = context.scaler.to_int(element.height)

          context.emit(Emf::Emr::Binary::Records::StretchDIBits,
                       i_type: STRETCHDIBITS,
                       rcl_bounds: bounds,
                       x_dest: x_dest,
                       y_dest: y_dest,
                       x_src: 0,
                       y_src: 0,
                       cx_src: dib_width(dib),
                       cy_src: dib_height(dib),
                       off_bmi_src: off_bmi,
                       cb_bmi_src: bmi_size,
                       off_bits_src: off_bits,
                       cb_bits_src: bits_size,
                       i_usage_src: 0, # DIB_RGB_COLORS
                       dw_rop: 0x00CC0020, # SRCCOPY
                       cx_dest: cx_dest,
                       cy_dest: cy_dest,
                       trailing: dib)
        end

        def dib_width(dib)
          dib.unpack1("V", offset: 4)
        end

        def dib_height(dib)
          dib.unpack1("V", offset: 8)
        end
      end
    end
  end
end
