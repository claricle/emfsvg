# frozen_string_literal: true

module Emfsvg
  module Svg
    module Elements
      # <path d="..."/>. Stores parsed PathData::Command list.
      class Path < Element
        ELEMENT_NAME = "path"
        Element.register("path", self)

        attr_reader :commands, :fill, :stroke, :clip_path, :line_record_kind, :path_record_kind

        def initialize(commands:, fill:, stroke:, clip_path: nil, line_record_kind: nil, path_record_kind: nil)
          @commands = commands
          @fill = fill
          @stroke = stroke
          @clip_path = clip_path
          @line_record_kind = line_record_kind
          @path_record_kind = path_record_kind
        end

        def self.from_node(node)
          source_tag = yield(node) if block_given?
          style = Stylable.parse_style(node)
          path_record_kind = canonical_path_record_kind(node, source_tag) if source_tag
          brush_fallback = source_tag && canonical_brush_fallback?(node, source_tag)
          if brush_fallback
            paint = style[:stroke].paint
            style[:stroke] = Svg::Stroke.new(paint: paint, raw_width: "1px", fallback_brush: paint)
          end
          style[:fill] = Svg::Paint.from_fill(node["style"].delete_prefix("fill:")) if path_record_kind == :bitblt
          new(
            commands: Svg::PathData::Parser.parse(node["d"]),
            line_record_kind: source_tag && (brush_fallback || canonical_polyline?(node, source_tag)) ? :polyline : nil,
            path_record_kind: path_record_kind,
            **style
          )
        end

        # A NULL pen uses its solid brush to draw open Polyline strokes. The
        # renderer writes fill=none even though that independent brush is set.
        def self.canonical_brush_fallback?(node, source_tag)
          number = "-?\\d+\\.\\d{4}"
          return false unless node["d"]&.match?(/\AM #{number},#{number}(?: L #{number},#{number})+ \z/)
          return false unless node["stroke"]&.match?(/\A#[0-9A-F]{6}\z/)

          source_tag == %(<path d="#{node['d']}" stroke-width="1px" stroke="#{node['stroke']}" fill="none" />)
        end
        private_class_method :canonical_brush_fallback?

        def self.canonical_path_record_kind(node, source_tag)
          arc_kind = canonical_arc_kind(node, source_tag)
          return arc_kind if arc_kind
          return :end_path if canonical_pending_path?(node, source_tag)
          return :fill_path if canonical_filled_curve?(node, source_tag)
          return :bitblt if canonical_bitblt?(node, source_tag)
          return :polypolygon if canonical_poly_polygon?(node, source_tag)
          return :stroke_and_fill_path if canonical_open_painted_path?(node, source_tag)
          return :polybezier_to if canonical_stroked_curve?(node, source_tag)
          return :stroke_path if canonical_orphan_or_empty_path?(node, source_tag)

          nil
        end
        private_class_method :canonical_path_record_kind

        # EndPath without a painting record has this exact invisible spelling.
        # Its geometry remains available to a following SelectClipPath.
        def self.canonical_pending_path?(node, source_tag)
          number = "-?\\d+\\.\\d{4}"
          node["d"]&.match?(/\AM #{number},#{number}(?: L #{number},#{number})+ \z/) &&
            source_tag == %(<path d="#{node['d']}" fill="none" stroke="none" />)
        end
        private_class_method :canonical_pending_path?

        # A pure cubic FillPath omits PolyBezier's extra current-position move.
        def self.canonical_filled_curve?(node, source_tag)
          number = "-?\\d+\\.\\d{4}"
          curve = " C #{number},#{number} #{number},#{number} #{number},#{number}"
          node["d"]&.match?(/\AM #{number},#{number}(?:#{curve})+ \z/) &&
            node["fill"]&.match?(/\A#[0-9A-F]{6}\z/) &&
            source_tag == %(<path d="#{node['d']}"  fill="#{node['fill']}" stroke="none" />)
        end
        private_class_method :canonical_filled_curve?

        # Path painting implicitly closes only the fill, retaining open strokes.
        # Fill-first output distinguishes it from unfilled Polyline/PolyBezier.
        def self.canonical_open_painted_path?(node, source_tag)
          number = "-?\\d+\\.\\d{4}"
          point = "#{number},#{number}"
          segment = "(?: L #{point}| C #{point} #{point} #{point})"
          node["d"]&.match?(/\AM #{point}(?:#{segment})+ \z/) && canonical_fill_first_style?(node, source_tag)
        end
        private_class_method :canonical_open_painted_path?

        # PolyBezier includes a separate current-position move in its output;
        # PolyBezierTo emits only its existing current position.
        def self.canonical_stroked_curve?(node, source_tag)
          number = "-?\\d+\\.\\d{4}"
          point = "#{number},#{number}"
          node["d"]&.match?(/\AM #{point}(?: C #{point} #{point} #{point})+ \z/) &&
            canonical_stroked_path?(node, source_tag, fill_gap: true)
        end
        private_class_method :canonical_stroked_curve?

        # A stroked EMF path can start with LineTo or contain no figures at
        # all. Only the renderer's exact spelling carries that provenance.
        def self.canonical_orphan_or_empty_path?(node, source_tag)
          number = "-?\\d+\\.\\d{4}"
          data = node["d"]
          return false unless data == "" || data&.match?(/\AL #{number},#{number}(?: [ML] #{number},#{number})* \z/)

          canonical_stroked_path?(node, source_tag)
        end
        private_class_method :canonical_orphan_or_empty_path?

        # Zero-source BitBlt emits a style-first rectangle without a trailing
        # space after Z. Only that exact spelling carries record provenance.
        def self.canonical_bitblt?(node, source_tag)
          number = "-?\\d+\\.\\d{4}"
          rectangle = /
            \AM[ ](?<x>#{number}),(?<y>#{number})
            [ ]L[ ](?<right>#{number}),\k<y>
            [ ]L[ ]\k<right>,(?<bottom>#{number})
            [ ]L[ ]\k<x>,\k<bottom>[ ]Z\z
          /x
          node["style"]&.match?(/\Afill:#[0-9a-f]{6}\z/) &&
            node["d"]&.match?(rectangle) &&
            source_tag == %(<path style="#{node['style']}" d="#{node['d']}" />)
        end
        private_class_method :canonical_bitblt?

        # Only the exact legacy renderer spelling provides record provenance.
        # Ordinary SVG paths keep the existing translation strategy.
        def self.canonical_polyline?(node, source_tag)
          number = "-?\\d+\\.\\d{4}"
          return false unless node["d"]&.match?(/\AM #{number},#{number} L #{number},#{number} \z/)

          canonical_stroked_path?(node, source_tag)
        end
        private_class_method :canonical_polyline?

        def self.canonical_arc_kind(node, source_tag)
          number = "-?\\d+\\.\\d{4}"
          arc = /
            \AM[ ]#{number},#{number}[ ]M[ ]#{number},#{number}
            [ ]A[ ]#{number},#{number}[ ]0[ ](?<sweep>[01])[ ]\k<sweep>[ ]#{number},#{number}
            [ ](?<closure>(?:L[ ]#{number},#{number}[ ])?Z[ ])?\z
          /x
          match = arc.match(node["d"].to_s)
          return unless match

          kind = if match[:closure]
                   match[:closure].start_with?("L") ? :pie : :chord
                 else
                   :arc
                 end
          kind if canonical_stroked_path?(node, source_tag, fill_gap: true, closed: kind != :arc)
        end
        private_class_method :canonical_arc_kind

        def self.canonical_stroked_path?(node, source_tag, fill_gap: false, closed: false)
          number = "-?\\d+\\.\\d{4}"
          return false unless node["stroke"]&.match?(/\A#[0-9A-Fa-f]{6}\z/)
          return false unless node["stroke-width"]&.match?(/\A(?:#{number}|1px)\z/)
          return false unless %w[round square butt].include?(node["stroke-linecap"])
          return false unless %w[round bevel miter].include?(node["stroke-linejoin"])
          return false unless closed ? node["fill"]&.match?(/\A#[0-9A-Fa-f]{6}\z/) : node["fill"] == "none"

          expected = +"<path "
          if node["clip-path"]
            return false unless node["clip-path"].match?(/\Aurl\(#clip-\d+\)\z/)

            expected << %( clip-path="#{node['clip-path']}" )
          end
          expected << %(d="#{node['d']}" stroke="#{node['stroke']}" stroke-width="#{node['stroke-width']}" )
          expected << %(stroke-dasharray="#{node['stroke-dasharray']}" ) if node["stroke-dasharray"]
          expected << %( stroke-linecap="#{node['stroke-linecap']}"  stroke-linejoin="#{node['stroke-linejoin']}" )
          expected << %( stroke-miterlimit="#{node['stroke-miterlimit']}" ) if node["stroke-miterlimit"]
          expected << " " if fill_gap
          expected << %(fill="#{node['fill']}")
          expected << " " if closed
          expected << " />"
          source_tag == expected
        end
        private_class_method :canonical_stroked_path?

        # PolyPolygon's C renderer has a distinctive fill-first start tag and
        # retains a trailing space after Z. Preserve that record only for the
        # exact spelling emitted by the renderer; ordinary closed paths use
        # Polygon as before.
        def self.canonical_poly_polygon?(node, source_tag)
          number = "-?\\d+\\.\\d{4}"
          node["d"]&.match?(/\AM #{number},#{number}(?: L #{number},#{number})+ Z \z/) &&
            canonical_fill_first_style?(node, source_tag)
        end
        private_class_method :canonical_poly_polygon?

        def self.canonical_fill_first_style?(node, source_tag)
          number = "-?\\d+\\.\\d{4}"
          return false unless node["fill"]&.match?(/\A#[0-9A-F]{6}\z/)
          return false unless node["stroke"]&.match?(/\A#[0-9A-F]{6}\z/)
          return false unless node["stroke-width"]&.match?(/\A(?:#{number}|1px)\z/)
          return false unless %w[round square butt].include?(node["stroke-linecap"])
          return false unless %w[round bevel miter].include?(node["stroke-linejoin"])
          return false if node["stroke-dasharray"]

          expected = %(<path d="#{node['d']}"  fill="#{node['fill']}" stroke="#{node['stroke']}" )
          expected << %(stroke-width="#{node['stroke-width']}"  stroke-linecap="#{node['stroke-linecap']}" )
          expected << %( stroke-linejoin="#{node['stroke-linejoin']}" )
          if node["stroke-miterlimit"]
            return false unless node["stroke-linejoin"] == "miter"

            expected << %( stroke-miterlimit="#{node['stroke-miterlimit']}" )
          end
          expected << "/>"
          source_tag == expected
        end
        private_class_method :canonical_fill_first_style?
      end
    end
  end
end
