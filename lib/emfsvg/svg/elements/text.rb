# frozen_string_literal: true

require "emf"

module Emfsvg
  module Svg
    module Elements
      # <text x y font-family font-size font-weight fill>content</text>
      # v1: single run, no <tspan>, no textPath. Content is read from the
      # element's text node.
      class Text < Element
        ELEMENT_NAME = "text"
        Element.register("text", self)

        # Recovered LOGFONT rotation and vertical alignment, separate from SVG affine transforms.
        Rotation = Struct.new(:angle, :vertical_alignment, :escapement, :native_height, :native_y, keyword_init: true)

        # The font attributes of a <text> element.
        Font = Struct.new(:family, :point_size, :weight, :style, :rotation, keyword_init: true)

        attr_reader :x, :y, :content, :font, :text_anchor, :fill, :stroke,
                    :clip_path, :transform_matrix, :empty_cdata_content, :canonical_text_rotation

        def initialize(x:, y:, content:, font:, text_anchor:, fill:, stroke:, clip_path: nil,
                       transform_matrix: Emf::Model::Geometry::Matrix.identity,
                       empty_cdata_content: false, canonical_text_rotation: nil)
          @x = x
          @y = y
          @content = content
          @font = font
          @text_anchor = text_anchor
          @fill = fill
          @stroke = stroke
          @clip_path = clip_path
          @transform_matrix = transform_matrix
          @empty_cdata_content = empty_cdata_content
          @canonical_text_rotation = canonical_text_rotation
        end

        def font_family = font.family

        def font_size = font.point_size

        def font_weight = font.weight

        def font_style = font.style

        def transformed?
          !transform_matrix.identity?
        end

        def self.from_node(node)
          rotation = canonical_rotation(node)
          new(
            x: AttributeParser.float(node["x"]),
            y: AttributeParser.float(node["y"]),
            content: node.text,
            empty_cdata_content: node.children.any? do |child|
              child.is_a?(Leptris::XML::CDATA) && child.content.empty?
            end,
            font: Font.new(
              family: node["font-family"],
              point_size: AttributeParser.float(node["font-size"], default: 12.0),
              weight: parse_weight(node["font-weight"]),
              style: node["font-style"],
              rotation: rotation&.angle
            ),
            text_anchor: node["text-anchor"] || "start",
            canonical_text_rotation: rotation,
            transform_matrix: Svg::TransformParser.parse(rotation ? nil : node["transform"]),
            **Stylable.parse_style(node)
          )
        end

        # Canonical LOGFONT output independently rounds size, pivot and offset.
        # Intersect their four-decimal source intervals instead of inferring an
        # arbitrary affine transform. TA_TOP prints the pivot as the displayed y.
        def self.canonical_rotation(node)
          return if node["dx"] || node["dy"]

          decimal = "(-?\\d+\\.\\d{4})"
          pattern = /\Arotate\((0|-?[1-9]\d*), #{decimal}, #{decimal}\) translate\(0, #{decimal}\)\z/
          match = node["transform"]&.match(pattern)
          return unless match

          angle = match[1].to_i
          return unless angle.between?(-359, 359)

          x, pivot, offset = match.captures.drop(1).map(&:to_r)
          return unless x == AttributeParser.float(node["x"]).to_s.to_r

          y = AttributeParser.float(node["y"]).to_s.to_r
          height = AttributeParser.float(node["font-size"], default: 12.0).to_s.to_r
          half_unit = Rational(1, 20_000)
          low = [(height - half_unit) * Rational(9, 10), offset - half_unit].max
          high = [(height + half_unit) * Rational(9, 10), offset + half_unit].min
          return unless low < high

          alignment = if pivot == y
                        height.zero? ? :baseline : :top
                      elsif [low, pivot - y - (2 * half_unit)].max < [high, pivot - y + (2 * half_unit)].min
                        :baseline
                      end
          return unless alignment

          native_height, native_y = recover_baseline(height, y, pivot, offset) if alignment == :baseline
          Rotation.new(angle: angle, vertical_alignment: alignment, escapement: angle.zero? ? 1 : -angle * 10,
                       native_height: native_height, native_y: native_y)
        end

        # A four-decimal native grid cannot always reproduce independently rounded
        # height, baseline and pivot. Choose an interior point of all four source
        # intervals; the handler uses a finer native mapping only for this case.
        def self.recover_baseline(height, y, pivot, offset)
          return if format("%.4f", y.to_f + (height.to_f * 0.9)) == format("%.4f", pivot)

          half = Rational(1, 20_000)
          ratio = Rational(9, 10)
          low = [height - half, (offset - half) / ratio, (pivot - y - (2 * half)) / ratio].max
          high = [height + half, (offset + half) / ratio, (pivot - y + (2 * half)) / ratio].min
          return unless low < high

          native_height = ((low + high) / 2 * 1_000_000).round / 1_000_000.0
          low_y = [y - half, pivot - half - (native_height.to_r * ratio)].max
          high_y = [y + half, pivot + half - (native_height.to_r * ratio)].min
          return unless low_y < high_y

          native_y = ((low_y + high_y) / 2 * 1_000_000).round / 1_000_000.0
          actual = [native_height, native_y, native_height * 0.9, native_y + (native_height * 0.9)]
          expected = [height, y, offset, pivot]
          return unless actual.map { |value| format("%.4f", value) } == expected.map { |value| format("%.4f", value) }

          [native_height, native_y]
        end

        def self.parse_weight(value)
          return 0 if value.nil?
          return 400 if value == "normal"

          value == "bold" ? 700 : value.to_i
        end

        def italic?
          font_style == "italic"
        end
      end
    end
  end
end
