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
        @resolved = {}
      end

      def register(clip_path)
        @resolved.clear
        @clip_paths[clip_path.id] = clip_path
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
        registry
      end

      def self.collect_clip_paths(element, registry)
        return unless element

        registry.register(element) if element.is_a?(Elements::ClipPath)
        element.children.each { |c| collect_clip_paths(c, registry) }
      end

      private

      def resolve(clip_path_attr)
        match = clip_path_attr.match(URL_RE)
        match && @clip_paths[match[1]]
      end
    end
  end
end
