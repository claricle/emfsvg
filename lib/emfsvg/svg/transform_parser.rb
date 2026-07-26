# frozen_string_literal: true

module Emfsvg
  module Svg
    # Parse SVG `transform="..."` attribute syntax into a single
    # `Emf::Model::Geometry::Matrix`. Handles translate(), scale(),
    # rotate(), matrix(), skewX(), skewY().
    #
    # Convention: the emf gem's Matrix uses EMF's row-vector layout
    # (v_new = v * M) — same as emfsvg's existing emr_visitor multiply.
    # SVG `transform="A B"` means "apply A first, then B to the result"
    # in row-vector terms, which equals the matrix product A * B.
    module TransformParser
      module_function

      TRANSFORM_FN_RE = /([a-zA-Z]+)\s*\(([^)]*)\)/

      def parse(string)
        return Emf::Model::Geometry::Matrix.identity if string.nil? || string.strip.empty?

        # Row-vector convention: v_new = v * M. SVG `transform="A B"`
        # applies B first then A to local coords, which in row-vector
        # equals the product B * A. Scanning left-to-right we compose
        # on the LEFT so each new function pre-multiplies the accumulator.
        string.scan(TRANSFORM_FN_RE).inject(Emf::Model::Geometry::Matrix.identity) do |composed, (name, args_str)|
          args = args_str.split(/[\s,]+/).map(&:to_f)
          fn_matrix = build_function(name.downcase, args)
          multiply(fn_matrix, composed)
        end
      end

      def build_function(name, args)
        case name
        when "matrix" then from_matrix_args(args)
        when "translate" then translate_matrix(*args)
        when "scale" then scale_matrix(*args)
        when "rotate" then rotate_matrix(*args)
        when "skewx" then skewx_matrix(args.first)
        when "skewy" then skewy_matrix(args.first)
        else
          raise FormatError, "unknown SVG transform function: #{name}"
        end
      end

      def from_matrix_args(args)
        raise FormatError, "matrix() requires 6 args" if args.size != 6

        Emf::Model::Geometry::Matrix.new(
          m11: args[0], m12: args[1], m21: args[2], m22: args[3],
          dx: args[4], dy: args[5]
        )
      end

      def translate_matrix(*args)
        tx = args.fetch(0, 0.0)
        ty = args.fetch(1, 0.0)
        Emf::Model::Geometry::Matrix.new(
          m11: 1.0, m12: 0.0, m21: 0.0, m22: 1.0,
          dx: tx, dy: ty
        )
      end

      def scale_matrix(*args)
        sx = args.fetch(0, 1.0)
        sy = args.fetch(1, sx)
        Emf::Model::Geometry::Matrix.new(
          m11: sx, m12: 0.0, m21: 0.0, m22: sy,
          dx: 0.0, dy: 0.0
        )
      end

      # SVG rotate(angle) is visually clockwise (Y grows downward).
      # With the emf gem's row-vector matrix layout, the equivalent
      # transform applied around (cx, cy) is: T(-cx,-cy) * R * T(cx,cy).
      # (The SVG spec text writes it as T(cx,cy) * R * T(-cx,-cy), but
      # that's column-vector notation — row-vector reverses the order.)
      def rotate_matrix(*args)
        deg = args.fetch(0, 0.0)
        cx = args.fetch(1, 0.0)
        cy = args.fetch(2, 0.0)
        rad = deg * Math::PI / 180.0
        cos = Math.cos(rad)
        sin = Math.sin(rad)
        rot = Emf::Model::Geometry::Matrix.new(
          m11: cos, m12: sin, m21: -sin, m22: cos,
          dx: 0.0, dy: 0.0
        )
        return rot if cx.zero? && cy.zero?

        multiply(multiply(translate_matrix(-cx, -cy), rot), translate_matrix(cx, cy))
      end

      def skewx_matrix(deg)
        rad = deg * Math::PI / 180.0
        Emf::Model::Geometry::Matrix.new(
          m11: 1.0, m12: 0.0, m21: Math.tan(rad), m22: 1.0,
          dx: 0.0, dy: 0.0
        )
      end

      def skewy_matrix(deg)
        rad = deg * Math::PI / 180.0
        Emf::Model::Geometry::Matrix.new(
          m11: 1.0, m12: Math.tan(rad), m21: 0.0, m22: 1.0,
          dx: 0.0, dy: 0.0
        )
      end

      # Row-vector matrix multiply: v * (a * b) = (v * a) * b. Matches
      # emfsvg's emr_visitor#multiply_matrix formula.
      def multiply(a, b)
        Emf::Model::Geometry::Matrix.new(
          m11: (a.m11 * b.m11) + (a.m12 * b.m21),
          m12: (a.m11 * b.m12) + (a.m12 * b.m22),
          m21: (a.m21 * b.m11) + (a.m22 * b.m21),
          m22: (a.m21 * b.m12) + (a.m22 * b.m22),
          dx: (a.dx * b.m11) + (a.dy * b.m21) + b.dx,
          dy: (a.dx * b.m12) + (a.dy * b.m22) + b.dy
        )
      end
    end
  end
end
