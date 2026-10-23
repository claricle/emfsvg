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

      private

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
