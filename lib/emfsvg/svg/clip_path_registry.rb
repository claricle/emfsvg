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
      end

      def register(clip_path)
        @clip_paths[clip_path.id] = clip_path
      end

      def referenced?(id)
        @references.key?(id)
      end

      def reference(clip_path_attr)
        match = clip_path_attr&.match(URL_RE)
        @references[match[1]] = true if match
      end

      def lookup(clip_path_attr)
        return nil if clip_path_attr.nil?

        match = clip_path_attr.match(URL_RE)
        return nil unless match

        @clip_paths[match[1]]
      end

      def self.from_document(document)
        registry = new
        collect_clip_paths(document.root_element, registry)
        registry
      end

      def self.collect_clip_paths(element, registry)
        return unless element

        registry.register(element) if element.is_a?(Elements::ClipPath)
        registry.reference(element.clip_path) if element.respond_to?(:clip_path)
        element.children.each { |c| collect_clip_paths(c, registry) }
      end
    end
  end
end
