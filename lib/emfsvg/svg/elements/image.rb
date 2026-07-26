# frozen_string_literal: true

module Emfsvg
  module Svg
    module Elements
      # <image x y width height xlink:href="data:..."/>
      # v1: data: URIs only (PNG, JPEG, base64-encoded). File/http URIs
      # are out of scope.
      class Image < Element
        ELEMENT_NAME = "image"
        Element.register("image", self)

        attr_reader :x, :y, :width, :height, :href, :fill, :stroke, :clip_path

        def initialize(x:, y:, width:, height:, href:, fill: nil, stroke: nil, clip_path: nil)
          @x = x
          @y = y
          @width = width
          @height = height
          @href = href
          @fill = fill
          @stroke = stroke
          @clip_path = clip_path
        end

        def self.from_node(node)
          href = node["xlink:href"] || node["href"]
          new(
            x: AttributeParser.float(node["x"]),
            y: AttributeParser.float(node["y"]),
            width: AttributeParser.float(node["width"]),
            height: AttributeParser.float(node["height"]),
            href: href,
            **Stylable.parse_style(node)
          )
        end

        def data_uri?
          href&.start_with?("data:")
        end

        def mime_type
          return nil unless data_uri?

          match = href.match(/\Adata:([^;,]+)/)
          match ? match[1] : nil
        end

        def decoded_bytes
          return nil unless data_uri?

          match = href.match(/\Adata:[^;,]+(?:;[^,]*)*,(.*)\z/m)
          return nil unless match

          payload = match[1]
          base64? ? Base64.decode64(payload) : payload
        end

        def base64?
          href.include?(";base64,")
        end
      end
    end
  end
end
