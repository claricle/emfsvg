# frozen_string_literal: true

module Emfsvg
  module Svg
    module Elements
      # <defs>: container for reusable definitions (clipPath, etc.).
      # Children are NOT rendered directly; they are referenced by id.
      class Defs < Element
        ELEMENT_NAME = "defs"
        Element.register("defs", self)

        HREF_ATTRIBUTES = %w[href xlink:href].freeze
        CanonicalPattern = Struct.new(:image, keyword_init: true)

        attr_reader :children, :unused_pattern

        def initialize(children:, unused_pattern: nil)
          @children = children
          @unused_pattern = unused_pattern
        end

        def self.from_node(node, &source_tag)
          new(children: node.element_children.map { |c| Element.from_node(c, &source_tag) },
              unused_pattern: canonical_unused_pattern(node))
        end

        # The renderer emits this pair when a DIB brush is created, even if
        # never selected. Keep that provenance separate from ordinary resources.
        def self.canonical_unused_pattern(node)
          image, pattern = node.element_children
          return unless node.element_children.size == 2 && node.attribute_nodes.empty?
          return unless image.name == "image" && pattern.name == "pattern"

          id = image["id"]
          width = image["width"]
          height = image["height"]
          return unless id&.match?(/\Aimg-[1-9]\d*\z/)
          return unless [width, height].all? { |v| v&.match?(/\A[1-9]\d*\z/) }
          return unless canonical_image_attributes?(image, id, width, height)
          return unless pattern.attribute_pairs == [["id", "#{id}-ref"], %w[x 0], %w[y 0],
                                                    ["width", width], ["height", height],
                                                    %w[patternUnits userSpaceOnUse]]

          use = pattern.element_children.first
          return unless pattern.element_children.size == 1 && use.name == "use"
          return unless canonical_use?(use, id)
          return if referenced_pattern?(node.document.root, [id, "#{id}-ref"], use)

          CanonicalPattern.new(image: Image.from_node(image)).freeze
        end
        private_class_method :canonical_unused_pattern

        def self.canonical_use?(use, id)
          use.attribute_pairs == [["id", "#{id}-ign"], ["xlink:href", "##{id}"]] && use.element_children.empty?
        end
        private_class_method :canonical_use?

        def self.canonical_image_attributes?(image, id, width, height)
          image.element_children.empty? && image["xlink:href"]&.start_with?("data:image/png;base64,") &&
            image.attribute_pairs == [["id", id], ["x", "0"], ["y", "0"], ["width", width], ["height", height],
                                      ["xlink:href", image["xlink:href"]], ["preserveAspectRatio", "none"]]
        end
        private_class_method :canonical_image_attributes?

        def self.referenced_pattern?(node, ids, internal_use)
          return false if node == internal_use
          # Stylesheets can select resources without a local presentation attribute.
          return true if node.name == "style"

          referenced = node.attribute_pairs.any? do |name, value|
            ids.any? do |id|
              (HREF_ATTRIBUTES.include?(name) && value == "##{id}") ||
                value.match?(/url\(\s*["']?\##{Regexp.escape(id)}["']?\s*\)/)
            end
          end
          referenced || node.element_children.any? { |child| referenced_pattern?(child, ids, internal_use) }
        end
        private_class_method :referenced_pattern?
      end
    end
  end
end
