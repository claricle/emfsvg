# frozen_string_literal: true

require "stringio"
require "zlib"

module Emfsvg
  # Minimal pure-Ruby PNG encoder. Encodes an RGBA pixel buffer as a
  # PNG with colour type 6 (8-bit RGBA), no interlacing, no ancillary
  # chunks. Output is suitable for `data:image/png;base64,...` URIs.
  class PngEncoder
    class << self
      def encode(width, height, rgba_bytes)
        return "" if width <= 0 || height <= 0

        header = chunk("IHDR", ihdr_payload(width, height))
        data = build_idat(width, height, rgba_bytes)
        idat = chunk("IDAT", data)
        iend = chunk("IEND", "")
        SIGNATURE + header + idat + iend
      end
    end

    SIGNATURE = [137, 80, 78, 71, 13, 10, 26, 10].pack("C*")

    class << self
      def chunk(type, payload)
        crc_input = type + payload
        [payload.bytesize].pack("N") + type + payload + [Zlib.crc32(crc_input)].pack("N")
      end

      def ihdr_payload(width, height)
        [width, height].pack("NN") + [8, 6, 0, 0, 0].pack("C*") # 8-bit, colour type 6 (RGBA)
      end

      def build_idat(width, height, rgba_bytes)
        raw = String.new(capacity: (width * height * 4) + height)
        stride = width * 4
        (0...height).each do |y|
          raw << "\x00" # filter type 0 (None)
          raw << rgba_bytes.bytes[y * stride, stride].pack("C*")
        end
        # Note: libemf2svg uses libpng which produces different (better-
        # compressed) output. Byte parity for images is not achievable
        # without a libpng binding.
        Zlib::Deflate.deflate(raw, 9)
      end
    end
  end
end
