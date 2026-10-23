# frozen_string_literal: true

module Emfsvg
  module Svg
    module Elements
      # <clipPath id="X">...</clipPath>: defines a clipping region.
      # Contains one or more child shapes whose union forms the clip.
      class ClipPath < Element
        ELEMENT_NAME = "clipPath"
        Element.register("clipPath", self)

        attr_reader :id, :children, :unused_rectangle_bounds

        def initialize(id:, children:, unused_rectangle_bounds: nil)
          @id = id
          @children = children
          @unused_rectangle_bounds = unused_rectangle_bounds
        end

        def self.from_node(node, &source_tag)
          new(
            id: node["id"],
            unused_rectangle_bounds: canonical_unused_rectangle(node, &source_tag),
            children: node.element_children.map { |c| Element.from_node(c, &source_tag) }
          )
        end

        # Only the renderer's exact rectangle spelling supports preservation of
        # an otherwise inert resource via IntersectClipRect followed by reset.
        def self.canonical_unused_rectangle(node)
          return unless node["id"]&.match?(/\Aclip-\d+\z/) && node.attribute_nodes.size == 1
          return unless node.element_children.size == 1 && block_given?

          path = node.element_children.first
          return unless path.name == "path" && path.attribute_nodes.map(&:name) == ["d"]

          number = "(-?\\d+\\.\\d{4})"
          lines = " L #{number},#{number}" * 4
          pattern = "\\AM #{number},#{number}#{lines} Z Z\\z"
          match = path["d"]&.match(Regexp.new(pattern))
          return unless match && yield(path) == %(<path d="#{path['d']}" />)

          left, top, right, top2, right2, bottom, left2, bottom2, left3, top3 = match.captures.map(&:to_f)
          return unless [left, top, right, bottom, left, top] == [left2, top2, right2, bottom2, left3, top3]
          return unless left <= right && top <= bottom

          [left, top, right, bottom]
        end
        private_class_method :canonical_unused_rectangle

        # Bounds [left, top, right, bottom] of the clip region for
        # IntersectClipRect emission. Handles three forms:
        #
        # 1. Single <rect> child — use rect bounds directly.
        # 2. Single <path> child whose d-string traces a rectangle
        #    (4 unique corners + close) — extract corner bounds.
        # 3. Anything else — use the union bounding box of all child
        #    geometry (lossy: curves flattened to bounds).
        #
        # Every shape that references the clip asks for these bounds, so
        # they are computed once and the (frozen) result is reused.
        def clip_bounds
          return @clip_bounds if defined?(@clip_bounds)

          @clip_bounds = compute_clip_bounds&.freeze
        end

        # Alias retained for backward compatibility with shared_gdi.rb.
        def rectangular_bounds
          clip_bounds
        end

        private

        def compute_clip_bounds
          return nil if children.empty?

          if children.size == 1
            child = children.first
            return rect_bounds(child) if child.is_a?(Elements::Rect)
            return path_rect_bounds(child) if child.is_a?(Elements::Path)
          end

          bounding_box_of(children)
        end

        def rect_bounds(rect)
          [rect.x, rect.y, rect.x + rect.width, rect.y + rect.height]
        end

        # emfsvg's IntersectClipRect renderer emits a 5-point closed
        # path: M X1,Y1 L X2,Y1 L X2,Y2 L X1,Y2 L X1,Y1 Z Z. Detect
        # that shape and recover (X1, Y1, X2, Y2).
        def path_rect_bounds(path)
          points = PathFlattenerForClip.new.flatten(path.commands)
          return nil unless points && points.size >= 4

          xs = points.map(&:first)
          ys = points.map(&:last)
          [xs.min, ys.min, xs.max, ys.max]
        end

        def bounding_box_of(elements)
          xs = []
          ys = []
          elements.each do |e|
            case e
            when Elements::Rect
              xs << e.x << (e.x + e.width)
              ys << e.y << (e.y + e.height)
            when Elements::Ellipse
              xs << (e.cx - e.rx) << (e.cx + e.rx)
              ys << (e.cy - e.ry) << (e.cy + e.ry)
            when Elements::Path
              points = PathFlattenerForClip.new.flatten(e.commands)
              next unless points

              points.each do |x, y|
                xs << x
                ys << y
              end
            end
          end
          return nil if xs.empty?

          [xs.min, ys.min, xs.max, ys.max]
        end

        # Minimal path flattener for clip extraction. Only handles
        # absolute M/L/H/V/Z — enough for emfsvg's rectangular clip
        # output. Relative commands and curves fall through (returns
        # nil → caller treats as non-rectangular).
        class PathFlattenerForClip
          def flatten(commands)
            points = []
            current = [0.0, 0.0]
            commands.each do |cmd|
              case cmd.letter
              when "M", "L"
                current = cmd.args
                points << current.dup
              when "H"
                current = [cmd.args.first, current.last]
                points << current.dup
              when "V"
                current = [current.first, cmd.args.first]
                points << current.dup
              when "Z"
                # close — ignored for bounds extraction
              else
                return nil
              end
            end
            points
          end
        end
      end
    end
  end
end
