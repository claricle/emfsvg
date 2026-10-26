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
        CanonicalPattern = Struct.new(:image, :id, keyword_init: true)

        attr_reader :children, :unused_pattern, :selected_pattern

        def initialize(children:, unused_pattern: nil, selected_pattern: nil)
          @children = children
          @unused_pattern = unused_pattern
          @selected_pattern = selected_pattern
        end

        def self.from_node(node, &source_tag)
          new(children: node.element_children.map { |c| Element.from_node(c, &source_tag) },
              unused_pattern: canonical_unused_pattern(node),
              selected_pattern: canonical_selected_pattern(node))
        end

        # The renderer emits this pair when a DIB brush is created, even if
        # never selected. Keep that provenance separate from ordinary resources.
        def self.canonical_unused_pattern(node, selected: false)
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

          return unless canonical_pattern_reference?(node.document.root, id, use, selected)

          CanonicalPattern.new(image: Image.from_node(image), id: "#{id}-ref").freeze
        end
        private_class_method :canonical_unused_pattern

        def self.canonical_pattern_reference?(root, id, use, selected)
          return selected_pattern_reference?(root, "#{id}-ref") if selected

          !referenced_pattern?(root, [id, "#{id}-ref"], use)
        end
        private_class_method :canonical_pattern_reference?

        def self.canonical_selected_pattern(node)
          canonical_unused_pattern(node, selected: true)
        end
        private_class_method :canonical_selected_pattern

        def self.selected_pattern_reference?(node, id)
          supported = %w[rect ellipse circle polygon polyline path]
          return true if supported.include?(node.name) && ["##{id}", "url(##{id})"].include?(node["fill"])

          node.element_children.any? { |child| selected_pattern_reference?(child, id) }
        end
        private_class_method :selected_pattern_reference?

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
              ((HREF_ATTRIBUTES.include?(name) || name == "fill") && value == "##{id}") ||
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
