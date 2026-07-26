# frozen_string_literal: true

module Emfsvg
  # Immutable clip region value object. Holds either a rectangular
  # bounds (most common case) or a complex path (for SelectClipPath
  # with arbitrary paths).
  #
  # Combine modes per MS-WMF 2.1.5:
  #   RGN_AND=1, RGN_OR=2, RGN_XOR=3, RGN_DIFF=4, RGN_COPY=5
  class ClipRegion
    RGN_AND = 1
    RGN_OR = 2
    RGN_XOR = 3
    RGN_DIFF = 4
    RGN_COPY = 5

    def initialize(bounds: nil, path_d: nil)
      @bounds = bounds
      @path_d = path_d
    end

    attr_reader :bounds, :path_d

    def empty?
      bounds.nil? && path_d.nil?
    end

    # SVG element body for the clip shape: `<rect .../>` or `<path .../>`.
    def to_svg_element(builder)
      if path_d
        builder.tag("path", { "d" => path_d }, single: true)
      elsif bounds
        builder.tag("rect", rect_attrs(bounds), single: true)
      end
    end

    # Combine with another region per the given mode.
    # For MVP we approximate: only AND and COPY are handled precisely;
    # OR/XOR/DIFF fall back to the new region's bounds.
    def combine(other, mode)
      case mode
      when RGN_AND
        return other if empty?
        return self if other.empty?

        ClipRegion.new(bounds: intersect_rects(bounds, other.bounds))
      else # RGN_COPY, RGN_OR, RGN_XOR, RGN_DIFF — MVP: use new region
        other
      end
    end

    private

    def rect_attrs(rect)
      {
        "x" => rect.left,
        "y" => rect.top,
        "width" => rect.right - rect.left,
        "height" => rect.bottom - rect.top
      }
    end

    def intersect_rects(a, b)
      return b unless a
      return a unless b

      Emf::Model::Geometry::Rect.new(
        left: [a.left, b.left].max,
        top: [a.top, b.top].max,
        right: [a.right, b.right].min,
        bottom: [a.bottom, b.bottom].min
      )
    end
  end
end
