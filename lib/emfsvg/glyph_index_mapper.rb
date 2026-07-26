# frozen_string_literal: true

require "open3"

module Emfsvg
  # Maps glyph indices to Unicode codepoints using the system font's
  # cmap table. Mirrors libemf2svg's fontindex_to_utf8 which uses
  # fontconfig + freetype. We use `fc-match` to find the font file
  # and fontisan to parse the cmap.
  #
  # The reverse cmap is cached per (font_family, weight, italic) triple
  # since parsing the cmap is expensive and the same font is typically
  # referenced many times.
  class GlyphIndexMapper
    ETO_GLYPH_INDEX = 0x0010 # per MS-WMF ExtTextOutOptions

    # Hebrew/Arabic charsets that need RTL reversal after mapping.
    HEBREW_CHARSET = 177
    ARABIC_CHARSET = 178

    def initialize
      @cache = {}
    end

    # Map an array of glyph indices to a UTF-8 string using the
    # font's reverse cmap. Mirrors libemf2svg's fontindex_to_utf8
    # + text_convert:
    #
    # 1. Build UTF-8 string with null chars (U+0000) for unmapped glyphs.
    # 2. If charset is Hebrew/Arabic, reverse the string (Ruby's
    #    String#reverse correctly handles multibyte UTF-8 chars).
    # 3. Truncate at the first null char — matches fprintf %s behavior.
    #
    # This means: for RTL languages, if ANY glyph is unmapped, the
    # reversed string may start with null → empty output.
    def map(glyph_ids, font_family:, weight:, italic:, charset:)
      reverse_map = build_reverse_map(font_family, weight, italic)
      return nil unless reverse_map

      codepoints = glyph_ids.map { |gid| reverse_map[gid] || 0 }
      utf8 = codepoints.pack("U*")

      if charset == HEBREW_CHARSET || charset == ARABIC_CHARSET
        utf8 = utf8.reverse
      end

      null_pos = utf8.index("\x00")
      utf8 = utf8[0, null_pos] if null_pos

      utf8
    end

    private

    def build_reverse_map(font_family, weight, italic)
      key = [font_family&.downcase, weight, italic]
      return @cache[key] if @cache.key?(key)

      path = find_font_path(font_family, weight, italic)
      return @cache[key] = nil unless path && File.exist?(path)

      begin
        reverse_map = parse_cmap_reverse(path)
        @cache[key] = reverse_map
      rescue StandardError
        @cache[key] = nil
      end
    end

    def find_font_path(font_family, weight, italic)
      return nil if font_family.nil? || font_family.empty?

      # Build fontconfig pattern matching libemf2svg's get_fontpath.
      pattern = font_family.dup
      stdout, _ = Open3.capture2("fc-match", "-f", "%{file}\n", pattern)
      path = stdout.strip
      path.empty? ? nil : path
    end

    # Parse a font file's cmap table and build a reverse map
    # {glyph_id => codepoint}. Uses fontisan's Cmap parser.
    def parse_cmap_reverse(font_path)
      require "fontisan"
      bytes = File.binread(font_path)
      num_tables = bytes[4, 2].unpack1("n").to_i
      cmap_offset = cmap_length = nil
      (0...num_tables).each do |i|
        off = 12 + i * 16
        tag = bytes[off, 4]
        next unless tag == "cmap"

        cmap_offset = bytes[off + 8, 4].unpack1("N")
        cmap_length = bytes[off + 12, 4].unpack1("N")
        break
      end
      return nil unless cmap_offset

      cmap_bytes = bytes[cmap_offset, cmap_length]
      cmap = Fontisan::Tables::Cmap.read(cmap_bytes)
      forward = cmap.unicode_mappings
      forward.each_with_object({}) do |(cp, gid), h|
        # Last codepoint wins (matches FreeType's FT_Get_Next_Char).
        h[gid] = cp
      end
    rescue LoadError, StandardError
      nil
    end
  end
end
