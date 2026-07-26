# frozen_string_literal: true

require "libpng"

module Emfsvg
  # Wraps the +libpng+ gem to encode an RGBA pixel buffer as a PNG.
  # Uses the standard libpng write API (png_create_write_struct +
  # png_write_png with PNG_TRANSFORM_IDENTITY) which matches
  # libemf2svg's rgb2png byte-for-byte. The simplified API
  # (Libpng.encode) uses a different filter heuristic that produces
  # different IDAT bytes.
  class PngEncoder
    class << self
      def encode(width, height, rgba_bytes)
        return "" if width <= 0 || height <= 0
        return "" if rgba_bytes.nil? || rgba_bytes.bytesize < (width * height * 4)

        png = Libpng.encode_standard(width, height, rgba_bytes, pixel_format: "RGBA")
        # Replicate libemf2svg's fmem padding: round up to next multiple
        # of 3 bytes by appending zero bytes. Without this the base64
        # output has `==` padding instead of the trailing `AA`/`A=`/``
        # that libemf2svg produces.
        rem = png.bytesize % 3
        png << ("\x00" * ((3 - rem) % 3)) if rem != 0
        png
      end
    end
  end
end
