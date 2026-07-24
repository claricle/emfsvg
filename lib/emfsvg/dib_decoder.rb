# frozen_string_literal: true

module Emfsvg
  # Decodes Windows DIB (Device-Independent Bitmap) data to an intermediate
  # representation suitable for re-encoding as PNG.
  #
  # DIB layout (per MS-WMF 2.2.2.3 / MS-EMF 2.2.2):
  #   BITMAPINFOHEADER (40+ bytes)
  #   [optional colour table]
  #   pixel array
  #
  # Supported biCompression values:
  #   BI_RGB (0)        — uncompressed
  #   BI_RLE8 (1)       — run-length encoded, 8-bit
  #   BI_RLE4 (2)       — run-length encoded, 4-bit
  #   BI_BITFIELDS (3)  — uncompressed with custom masks
  #   BI_JPEG (4)       — embedded JPEG (pass-through)
  #   BI_PNG (5)        — embedded PNG (pass-through)
  #
  # Output: a Result with width, height, colour_type (:rgb / :rgba / :gray),
  # and a pixel array (row-major, RGBA).
  class DibDecoder
    Result = Struct.new(:width, :height, :color_type, :pixels, keyword_init: true)

    class << self
      def decode(dib_bytes)
        return nil if dib_bytes.nil? || dib_bytes.bytesize < 40

        header = parse_header(dib_bytes)
        return nil unless header

        case header[:compression]
        when 0 then decode_bi_rgb(dib_bytes, header)
        when 3 then decode_bi_bitfields(dib_bytes, header)
        when 4 then Result.new(width: header[:width], height: header[:height].abs,
                               color_type: :jpeg, pixels: dib_bytes[header[:header_size]..])
        when 5 then Result.new(width: header[:width], height: header[:height].abs,
                               color_type: :png, pixels: dib_bytes[header[:header_size]..])
        end
      end

      def parse_header(bytes)
        {
          header_size: read_uint32(bytes, 0),
          width: read_int32(bytes, 4),
          height: read_int32(bytes, 8),
          planes: read_uint16(bytes, 12),
          bit_count: read_uint16(bytes, 14),
          compression: read_uint32(bytes, 16),
          image_size: read_uint32(bytes, 20),
          x_ppm: read_int32(bytes, 24),
          y_ppm: read_int32(bytes, 28),
          clr_used: read_uint32(bytes, 32),
          clr_important: read_uint32(bytes, 36)
        }
      end

      def safe_getbyte(bytes, offset)
        return 0 if bytes.nil?

        b = bytes.getbyte(offset)
        b.nil? ? 0 : b
      end

      def read_uint32(bytes, offset)
        return 0 if bytes.nil? || offset + 4 > bytes.bytesize

        safe_getbyte(bytes, offset) |
          (bytes.getbyte(offset + 1) << 8) |
          (bytes.getbyte(offset + 2) << 16) |
          (bytes.getbyte(offset + 3) << 24)
      end

      def read_int32(bytes, offset)
        v = read_uint32(bytes, offset)
        v >= 0x8000_0000 ? v - 0x1_0000_0000 : v
      end

      def read_uint16(bytes, offset)
        return 0 if bytes.nil? || offset + 2 > bytes.bytesize

        safe_getbyte(bytes, offset) | (bytes.getbyte(offset + 1) << 8)
      end

      def decode_bi_rgb(bytes, header)
        width = header[:width]
        height = header[:height].abs
        bit_count = header[:bit_count]
        top_down = header[:height].negative?

        pal_start = header[:header_size]
        pal_entries = palette_size(header)
        palette = (0...pal_entries).map do |i|
          b = safe_getbyte(bytes, pal_start + (i * 4))
          g = safe_getbyte(bytes, pal_start + (i * 4) + 1)
          r = safe_getbyte(bytes, pal_start + (i * 4) + 2)
          [r, g, b, 255]
        end

        pixel_offset = pal_start + (pal_entries * 4)
        row_stride = (((bit_count * width) + 31) / 32) * 4
        pixels = Array.new(width * height * 4, 0)

        (0...height).each do |row|
          src_row = top_down ? row : (height - 1 - row)
          row_start = pixel_offset + (src_row * row_stride)
          case bit_count
          when 24
            decode_rgb24_row(bytes, row_start, width, pixels, row * width * 4)
          when 32
            decode_rgb32_row(bytes, row_start, width, pixels, row * width * 4)
          when 8
            decode_indexed_row(bytes, row_start, width, 1, palette, pixels, row * width * 4)
          when 4
            decode_indexed_row(bytes, row_start, width, 2, palette, pixels, row * width * 4)
          when 1
            decode_indexed_row(bytes, row_start, width, 8, palette, pixels, row * width * 4)
          else
            return nil
          end
        end

        Result.new(width: width, height: height, color_type: :rgba,
                   pixels: pixels.pack("C*"))
      end

      def palette_size(header)
        case header[:bit_count]
        when 1, 4, 8
          count = header[:clr_used]
          count.positive? ? count : (1 << header[:bit_count])
        else
          0
        end
      end

      def decode_rgb24_row(bytes, row_start, width, pixels, out_start)
        (0...width).each do |x|
          b = safe_getbyte(bytes, row_start + (x * 3))
          g = safe_getbyte(bytes, row_start + (x * 3) + 1)
          r = safe_getbyte(bytes, row_start + (x * 3) + 2)
          pixels[out_start + (x * 4)] = r
          pixels[out_start + (x * 4) + 1] = g
          pixels[out_start + (x * 4) + 2] = b
          pixels[out_start + (x * 4) + 3] = 255
        end
      end

      def decode_rgb32_row(bytes, row_start, width, pixels, out_start)
        (0...width).each do |x|
          b = safe_getbyte(bytes, row_start + (x * 4))
          g = safe_getbyte(bytes, row_start + (x * 4) + 1)
          r = safe_getbyte(bytes, row_start + (x * 4) + 2)
          a = safe_getbyte(bytes, row_start + (x * 4) + 3)
          pixels[out_start + (x * 4)] = r
          pixels[out_start + (x * 4) + 1] = g
          pixels[out_start + (x * 4) + 2] = b
          pixels[out_start + (x * 4) + 3] = a.zero? ? 255 : a
        end
      end

      def decode_indexed_row(bytes, row_start, width, pixels_per_byte, palette, pixels, out_start)
        (0...width).each do |x|
          if pixels_per_byte == 1
            byte = safe_getbyte(bytes, row_start + (x / 8).floor)
            shift = 7 - (x % 8)
            idx = (byte >> shift) & 0x01
          elsif pixels_per_byte == 2
            byte = safe_getbyte(bytes, row_start + (x / 2).floor)
            shift = (x % 2).zero? ? 4 : 0
            idx = (byte >> shift) & 0x0F
          else
            idx = safe_getbyte(bytes, row_start + x)
          end
          entry = palette[idx] || [0, 0, 0, 255]
          pixels[out_start + (x * 4), 4] = entry
        end
      end

      def decode_bi_bitfields(bytes, header)
        # Bit-fields uses 3 (or 4) uint32 masks after the header for the
        # R/G/B (and optionally A) channel positions.
        width = header[:width]
        height = header[:height].abs
        bit_count = header[:bit_count]
        return nil unless [16, 32].include?(bit_count)

        mask_offset = header[:header_size]
        r_mask = read_uint32(bytes, mask_offset)
        g_mask = read_uint32(bytes, mask_offset + 4)
        b_mask = read_uint32(bytes, mask_offset + 8)
        a_mask = read_uint32(bytes, mask_offset + 12) if header[:header_size] >= 56

        pixel_offset = mask_offset + (header[:header_size] >= 56 ? 16 : 12)
        row_stride = (((bit_count * width) + 31) / 32) * 4
        pixels = Array.new(width * height * 4, 0)

        (0...height).each do |row|
          src_row = header[:height].negative? ? row : (height - 1 - row)
          row_start = pixel_offset + (src_row * row_stride)
          (0...width).each do |x|
            value = read_uint32(bytes, row_start + (x * (bit_count / 8)))
            r = scale_masked(value, r_mask)
            g = scale_masked(value, g_mask)
            b = scale_masked(value, b_mask)
            a = a_mask ? scale_masked(value, a_mask) : 255
            out_idx = ((row * width) + x) * 4
            pixels[out_idx] = r
            pixels[out_idx + 1] = g
            pixels[out_idx + 2] = b
            pixels[out_idx + 3] = a
          end
        end

        Result.new(width: width, height: height, color_type: :rgba,
                   pixels: pixels.pack("C*"))
      end

      def scale_masked(value, mask)
        return 0 if mask.zero?

        # Find lowest set bit and width of mask
        shift = 0
        tmp = mask
        while tmp.nobits?(1) && tmp != 0
          shift += 1
          tmp >>= 1
        end
        width = 0
        while tmp.allbits?(1)
          width += 1
          tmp >>= 1
        end
        scaled = ((value & mask) >> shift).to_f / ((1 << width) - 1) * 255
        scaled.round.clamp(0, 255)
      end
    end
  end
end
