# frozen_string_literal: true

require "digest"
require "json"

module Emfsvg
  # Private, per-record spelling provenance for the owned SVG round-trip
  # contract. Reference C rendering ignores these comments. They never carry
  # complete SVG, and cannot alter the drawing's geometry or paint.
  module DrawingHint
    MAGIC = "emfsvg-draw:1:"
    MAX_BYTES = 512
    DRAW_TYPES = %i[BITBLT POLYLINE POLYLINE16 STRETCHDIBITS].map do |name|
      Emf::Emr::Binary::TypeCodes.const_get(name)
    end.freeze

    module_function

    def rectangle_values(source)
      return unless source && source.bytesize <= 256

      number = "-?\\d+(?:\\.\\d+)?"
      pattern = %r{\A<rect x="(#{number})" y="(#{number})" width="(#{number})" height="(#{number})" \
fill="(#[0-9A-F]{6})"/>\z}
      match = source&.match(pattern)
      match&.captures
    end

    def for_element(element)
      if element.is_a?(Svg::Elements::Rect) && element.serialization_hint && !element.clip_path
        ["rect", element.serialization_hint]
      elsif element.stroke&.canonical_cosmetic_dash && element.stroke.raw_width == "1.0000"
        ["stroke", [color_hex(element.stroke.paint.color)]]
      elsif element.is_a?(Svg::Elements::Image) && element.mime_type == "image/jpeg"
        ["jpeg", []]
      end
    end

    def color_hex(color)
      format("#%<red>02X%<green>02X%<blue>02X", red: color.red, green: color.green, blue: color.blue)
    end

    def encode(record, kind, values)
      MAGIC + JSON.generate("record" => fingerprint(record), "kind" => kind, "values" => values)
    end

    def fingerprint(record)
      Digest::SHA256.hexdigest(record.wire.to_binary_s)
    end

    def decode(wire)
      length = wire.cb_data.to_i
      return unless length.between?(MAGIC.bytesize, MAX_BYTES)

      data = wire.data.to_s
      return unless data.bytesize.between?(length, (length + 3) & ~3)
      return unless data.byteslice(length..).to_s.bytes.all?(&:zero?)
      return unless data.start_with?(MAGIC)

      hint = JSON.parse(data.byteslice(MAGIC.bytesize, length - MAGIC.bytesize))
      return unless hint.is_a?(Hash) && hint.keys.sort == %w[kind record values]
      return unless hint["record"].is_a?(String) && hint["record"].match?(/\A[0-9a-f]{64}\z/)
      return unless valid_values?(hint["kind"], hint["values"])

      hint
    rescue JSON::ParserError
      nil
    end

    def valid_values?(kind, values)
      return false unless values.is_a?(Array)

      case kind
      when "rect"
        values.size == 5 && values.first(4).all? do |value|
          value.is_a?(String) && value.match?(/\A-?\d+(?:\.\d+)?\z/)
        end &&
          values.last.is_a?(String) && values.last.match?(/\A#[0-9A-F]{6}\z/)
      when "stroke"
        values.size == 1 && values.first.is_a?(String) && values.first.match?(/\A#[0-9A-F]{6}\z/)
      when "jpeg"
        values.empty?
      else
        false
      end
    end
  end
end
