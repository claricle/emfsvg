# frozen_string_literal: true

require "emf"
require "base64"

module Emfsvg
  module Translation
    module Handlers
      # Translate <image href="data:image/png;base64,..."/> into
      # EMR_STRETCHDIBITS with an embedded BI_RGB DIB.
      #
      # v1 limitations:
      #   * PNG data URIs only. JPEG and other formats fall through silently.
      #   * No aspect-ratio handling (uses width/height verbatim).
      class ImageHandler
        include SharedGdi
        include Emf::Emr::Binary::TypeCodes

        # Fixed portion of StretchDIBits record: 8 (emr) + 16 (bounds) +
        # 6*4 (int32 src/dest dims) + 6*4 (off/cb/i_usage/dw_rop/cx/cy)
        # = 80 bytes.
        STRETCHDIBITS_FIXED_SIZE = 80

        def self.call(element, context)
          new.translate(element, context)
        end

        def translate(element, context)
          return unless element.data_uri?
          return unless element.mime_type == "image/png"

          dib = build_dib(element)
          return unless dib

          with_gdi_state(element, context) do
            emit_stretch_dibits(element, dib, context)
          end
        end

        private

        def build_dib(element)
          png = element.decoded_bytes
          return nil unless png

          decoded = PngDecoder.decode(png)
          return nil unless decoded

          DibEncoder.encode(decoded.width, decoded.height, decoded.pixels)
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
