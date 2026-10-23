# frozen_string_literal: true

module Emfsvg
  module Svg
    # Resolves `clip-path="url(#X)"` references to ClipPath value
    # objects. Built once per Svg::Document by walking the <defs>
    # section; queried by the translation layer when emitting clip
    # records for a shape.
    class ClipPathRegistry
      URL_RE = /\Aurl\(\s*#([^)\s]+)\s*\)\z/

      def initialize
        @clip_paths = {}
        @references = {}
        @resolved = {}
        @exports = {}
        @imports = {}
        @selected = {}
        @unused_selected = {}
        @interval_starts = {}
        @interval_ends = {}
      end

      def register(clip_path)
        @resolved.clear
        @clip_paths[clip_path.id] = clip_path
      end

      def referenced?(id)
        @references.key?(id)
      end

      def reference(clip_path_attr)
        match = clip_path_attr&.match(URL_RE)
        @references[match[1]] = @references.fetch(match[1], 0) + 1 if match
      end

      # Shapes reference the same few clips over and over, so each
      # distinct attribute value is resolved once (until the next
      # registration).
      def lookup(clip_path_attr)
        return nil if clip_path_attr.nil?

        @resolved.fetch(clip_path_attr) { @resolved[clip_path_attr] = resolve(clip_path_attr) }
      end

      def self.from_document(document)
        registry = new
        collect_clip_paths(document.root_element, registry)
        registry.plan_sibling_clips(document.root_element)
        registry.plan_selected_clips(document.root_element)
        registry.plan_clip_intervals(document.header_translate_group)
        registry.plan_text_clip_intervals(document.root_element)
        registry.plan_pending_clips(document.root_element, document.header_translate_group)
        registry
      end

      def self.collect_clip_paths(element, registry)
        return unless element

        registry.register(element) if element.is_a?(Elements::ClipPath)
        registry.reference(element.clip_path) if element.respond_to?(:clip_path)
        element.children.each { |c| collect_clip_paths(c, registry) }
      end

      def exported_clip(group)
        @exports[group]
      end

      def imported_clip(group)
        @imports[group]
      end

      def selected_clip(group)
        @selected[group]
      end

      # A pending native path and its definition must agree exactly, and every
      # remaining child must reference it. RestoreDC then bounds its lifetime.
      def plan_selected_clips(group)
        return unless group

        group.children.each { |child| plan_selected_clips(child) }
        clip = selected_group_clip(group)
        @selected[group] = clip if clip
      end

      # A canonical identity group containing only a definition can carry its
      # clip into the immediately following canonical drawing group. The sole
      # reference bounds the lifetime; Context also requires a known-empty clip.
      def plan_sibling_clips(parent)
        return unless parent

        parent.children.each { |child| plan_sibling_clips(child) }
        return unless parent.is_a?(Elements::Group) && parent.transform_matrix.identity?

        parent.children.each_cons(2) do |source, target|
          clip = sibling_clip(source, target)
          next unless clip

          @exports[source] = clip
          @imports[target] = clip
        end
      end

      def interval_start(element)
        @interval_starts[element]
      end

      def interval_end(element)
        @interval_ends[element]
      end

      def unused_selected_clip?(clip)
        @unused_selected.key?(clip)
      end

      # A definition immediately following its exact pending native path can
      # select that path. Exclusive adjacent image or path uses bound its lifetime;
      # an unused selection is reset before any later drawing.
      def plan_pending_clips(parent, header)
        return unless parent

        parent.children.each { |child| plan_pending_clips(child, header) }
        return unless parent.equal?(header) ||
                      (parent.is_a?(Elements::Group) && parent.canonical_matrix? && parent.transform_matrix.identity?)

        parent.children.each_cons(2).with_index do |(path, defs), index|
          next unless defs.is_a?(Elements::Defs) && defs.children.size == 1

          clip = defs.children.first
          next unless clip.is_a?(Elements::ClipPath) && matching_pending_clip?(path, clip)

          if referenced?(clip.id)
            plan_pending_draw_interval(parent.children.drop(index + 2), defs, clip)
          else
            @unused_selected[clip] = true
          end
        end
      end

      # A canonical rectangle may surround nested clips and then be reused.
      # Only flat, fully explicit built-in drawings participate. Unused defs
      # and text transformed under a different clip remain boundaries.
      def plan_clip_intervals(parent)
        return unless parent

        children = parent.children
        positions = children.each_index.group_by { |index| lookup(children[index].clip_path) }
        occupied = []
        candidates = positions.reject { |clip, indices| !clip || indices.size < 2 }
        candidates.sort_by { |_, indices| -(indices.last - indices.first) }.each do |clip, indices|
          range = indices.first..indices.last
          next unless compatible_interval?(range, occupied, children, clip)
          next unless clip.unused_rectangle_bounds
          next unless children[range].all? { |child| interval_child?(child, clip) }

          @interval_starts[children[range.begin]] = clip
          @interval_ends[children[range.end]] = clip
          occupied << range
        end
      end

      # Canonical text draws can share a clip across a painted native path,
      # whose renderer spelling omits the clipping attribute. The exact three
      # drawing sequence and exclusive references bound this scope.
      def plan_text_clip_intervals(parent)
        return unless parent

        parent.children.each { |child| plan_text_clip_intervals(child) }
        return unless parent.is_a?(Elements::Group) && parent.canonical_matrix?

        parent.children.each_cons(5) do |previous, defs, first, path, last|
          clip = text_interval_clip(previous, defs, first, path, last)
          next unless clip

          @interval_starts[defs] = clip
          @interval_ends[last] = clip
        end
      end

      private

      def plan_pending_draw_interval(children, defs, clip)
        draws = children.take_while do |draw|
          supported = draw.instance_of?(Elements::Image) ||
                      (draw.instance_of?(Elements::Path) && draw.stroke && draw.fill &&
                        draw.path_record_kind != :end_path)
          supported && lookup(draw.clip_path).equal?(clip)
        end
        return if draws.empty? || @references[clip.id] != draws.size

        @interval_starts[defs] = clip
        @interval_ends[draws.last] = clip
      end

      # Crossing ranges cannot form native scopes. A nested range contains
      # only its own clip, so its final RestoreDC returns to the outer scope
      # even for renderers which retain restored snapshots.
      def compatible_interval?(range, occupied, children, clip)
        return false if occupied.any? do |prior|
          prior.cover?(range.begin) != prior.cover?(range.end)
        end

        parents = occupied.count { |prior| prior.cover?(range.begin) && prior.cover?(range.end) }
        uniform = children[range].all? { |child| child.is_a?(Elements::Defs) || lookup(child.clip_path).equal?(clip) }
        return !uniform if parents.zero?

        parents == 1 && uniform
      end

      def interval_child?(child, outer)
        return interval_definitions?(child) if child.is_a?(Elements::Defs)

        classes = [Elements::Path, Elements::Rect, Elements::Ellipse, Elements::Line,
                   Elements::Polyline, Elements::Polygon, Elements::Text, Elements::Image]
        return false unless classes.include?(child.class)
        return false if child.is_a?(Elements::Text) && child.transformed? && !lookup(child.clip_path).equal?(outer)
        return true if child.is_a?(Elements::Path) && !child.clip_path && child.stroke&.null_pen_fallback

        bounds = lookup(child.clip_path)&.unused_rectangle_bounds
        return false unless bounds

        left, top, right, bottom = outer.unused_rectangle_bounds
        bounds[0] >= left && bounds[1] >= top && bounds[2] <= right && bounds[3] <= bottom
      end

      def interval_definitions?(defs)
        # Creating an unselected canonical brush does not change the active clip.
        return true if defs.unused_pattern

        defs.children.all? do |clip|
          clip.is_a?(Elements::ClipPath) && clip.unused_rectangle_bounds && referenced?(clip.id)
        end
      end

      def text_interval_clip(previous, defs, first, path, last)
        return unless defs.is_a?(Elements::Defs) && defs.children.size == 1

        clip = defs.children.first
        return unless clip.is_a?(Elements::ClipPath) && @references[clip.id] == 2
        return unless [first, last].all? do |text|
          text.instance_of?(Elements::Text) && !text.transformed? && lookup(text.clip_path).equal?(clip)
        end
        return unless path.instance_of?(Elements::Path) && !path.clip_path
        return unless path.path_record_kind == :stroke_and_fill_path
        return clip if clip.unused_rectangle_bounds

        clip if matching_pending_clip?(previous, clip)
      end

      def matching_pending_clip?(path, clip)
        clip.selected_path_data && path.instance_of?(Elements::Path) &&
          path.path_record_kind == :end_path && !path.clip_path && matching_clip_path?(path, clip)
      end

      def selected_group_clip(group)
        return unless group.is_a?(Elements::Group) && group.canonical_matrix? && group.transform_matrix.identity?

        unused, path, defs, *draws = group.children
        return unless unused_clip_definitions?(unused)
        return unless path.is_a?(Elements::Path) && path.path_record_kind == :end_path && !path.clip_path
        return unless defs.is_a?(Elements::Defs) && defs.children.size == 1 && !draws.empty?

        clip = defs.children.first
        return unless clip.is_a?(Elements::ClipPath) && clip.selected_path_data
        return unless matching_clip_path?(path, clip)
        return unless exclusive_clip_draws?(draws, clip)

        clip
      end

      def exclusive_clip_draws?(draws, clip)
        @references[clip.id] == draws.size && draws.all? do |draw|
          draw.is_a?(Elements::Path) && lookup(draw.clip_path).equal?(clip)
        end
      end

      def unused_clip_definitions?(defs)
        defs.is_a?(Elements::Defs) && !defs.children.empty? && defs.children.all? do |child|
          child.is_a?(Elements::ClipPath) && child.unused_rectangle_bounds && !referenced?(child.id)
        end
      end

      def matching_clip_path?(path, clip)
        commands = Svg::PathData::Parser.parse(clip.selected_path_data)
        path.commands.map { |cmd| [cmd.letter, cmd.args] } == commands.map { |cmd| [cmd.letter, cmd.args] }
      end

      def sibling_clip(source, target)
        return unless source.is_a?(Elements::Group) && source.canonical_matrix? && source.transform_matrix.identity?
        return unless target.is_a?(Elements::Group) && target.canonical_matrix?
        return unless source.children.size == 1 && target.children.size == 1

        defs = source.children.first
        path = target.children.first
        return unless defs.is_a?(Elements::Defs) && defs.children.size == 1 && path.is_a?(Elements::Path)

        clip = defs.children.first
        return unless clip.is_a?(Elements::ClipPath) && clip.unused_rectangle_bounds
        return unless @references[clip.id] == 1 && lookup(path.clip_path).equal?(clip)

        clip
      end

      def resolve(clip_path_attr)
        match = clip_path_attr.match(URL_RE)
        match && @clip_paths[match[1]]
      end
    end
  end
end
