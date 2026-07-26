# frozen_string_literal: true

module Emfsvg
  # Encode RGBA pixels + dimensions to Windows DIB (BITMAPINFOHEADER +
  # pixel array) suitable for embedding in EMR_STRETCHDIBITS and
  # related records. The inverse of emfsvg's DibDecoder.
  #
  # Output layout (BI_RGB, 32-bpp, bottom-up):
  #   * BITMAPINFOHEADER (40 bytes)
  #   * pixel array (BGRA per pixel, row-major from bottom to top)
  module DibEncoder
    BITMAPINFOHEADER_SIZE = 40
    BI_RGB = 0

    module_function

    def encode(width, height, rgba_bytes)
      return "" if width <= 0 || height <= 0
      return "" if rgba_bytes.nil? || rgba_bytes.bytesize < (width * height * 4)

      header = build_header(width, height)
      pixels = bgra_pixel_array(width, height, rgba_bytes)
      header + pixels
    end

    def build_header(width, height)
      pixel_bytes = width * height * 4
      [
        BITMAPINFOHEADER_SIZE, # biSize  (uint32)
        width,                            # biWidth (int32)
        height,                           # biHeight (int32, positive = bottom-up)
        1,                                # biPlanes (uint16)
        32,                               # biBitCount (uint16)
        BI_RGB,                           # biCompression (uint32)
        pixel_bytes,                      # biSizeImage (uint32)
        2835,                             # biXPelsPerMeter (~72 DPI)
        2835,                             # biYPelsPerMeter
        0,                                # biClrUsed
        0                                 # biClrImportant
      ].pack("Vl<l<vvVVVVVV")
    end

    # Convert RGBA → BGRA (the byte order DIB expects), keeping the
    # bottom-up row order (rows reversed).
    def bgra_pixel_array(width, height, rgba_bytes)
      row_size = width * 4
      out = String.new capacity: width * height * 4
      (0...height).to_a.reverse_each do |src_row|
        row_start = src_row * row_size
        row_bytes = rgba_bytes.byteslice(row_start, row_size)
        out << swap_rb_in_row(row_bytes)
      end
      out
    end

    def swap_rb_in_row(row_bytes)
      bytes = row_bytes.dup
      (0...bytes.bytesize).step(4).each do |i|
        r = bytes.getbyte(i)
        b = bytes.getbyte(i + 2)
        bytes.setbyte(i, b)
        bytes.setbyte(i + 2, r)
      end
      bytes
    end
  end
end
