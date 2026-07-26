# frozen_string_literal: true

require "libpng"

module Emfsvg
  # Decode PNG bytes to RGBA pixels. Wraps the libpng simplified API.
  # Returns a Result with width, height, and a packed RGBA pixel buffer.
  module PngDecoder
    Result = Struct.new(:width, :height, :pixels, keyword_init: true)

    module_function

    def decode(png_bytes)
      return nil if png_bytes.nil? || png_bytes.empty?

      decoded = Libpng.decode(png_bytes, pixel_format: "RGBA")
      Result.new(width: decoded.width, height: decoded.height,
                 pixels: decoded.pixels)
    rescue Libpng::Error
      nil
    end
  end
end
