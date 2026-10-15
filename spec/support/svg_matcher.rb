# frozen_string_literal: true

require "leptris"

module Emfsvg
  # Lossy SVG comparison for round-trip testing. Two SVG documents are
  # "equal" if they have the same drawing element tree, same attributes
  # (with float tolerance for numeric values), same text content, and
  # the same multiset of `<defs>` resources (clipPath, pattern, image).
  #
  # Normalisations applied:
  #
  # * Numeric tokens within attribute values are compared with a
  #   configurable tolerance (default 0.5 pixels — catches sub-pixel
  #   rounding from int32 truncation while still flagging real offsets).
  # * Auto-generated IDs (`clip-<n>`, `img-<n>`, `img-<n>-ref`,
  #   `img-<n>-ign`) are canonicalised so BsdRand-driven IDs don't
  #   cause spurious mismatches.
  # * The libemf2svg typo `"0.00 00"` is canonicalised to `"0.0000"`.
  # * `<defs>` blocks are stripped from the in-order comparison and
  #   compared as a multiset across the whole document.
  # * `<g transform="M"><X/></g>` (single-child transform group) is
  #   rewritten to `<X transform="M"/>` so the two forms compare equal
  #   (SVG semantics: transform on element ≡ wrapped in g with same
  #   transform).
  # * Whitespace-only text nodes are ignored.
  module SvgMatcher
    DEFAULT_TOLERANCE = 0.5
    ID_REGEXPS = [
      /clip-\d+/,
      /img-\d+(-ref|-ign)?/
    ].freeze
    TYPO_NORMALISATIONS = {
      "0.00 00" => "0.0000" # libemf2svg typo in fix_broken_y translate
    }.freeze

    Result = Struct.new(:equal, :reason, keyword_init: true) do
      def ok?
        equal
      end
    end

    module_function

    def compare(svg_a, svg_b, tolerance: DEFAULT_TOLERANCE)
      comparator = Comparator.new(tolerance)
      doc_a = parse(svg_a)
      doc_b = parse(svg_b)
      return Result.new(equal: false, reason: "missing root") if doc_a.root.nil? || doc_b.root.nil?

      unless doc_a.root.name == doc_b.root.name
        return Result.new(equal: false,
                          reason: "root tag <#{doc_a.root&.name}> vs <#{doc_b.root&.name}>")
      end

      # Hoist <defs> contents into flat multisets.
      defs_a = collect_defs_children(doc_a.root)
      defs_b = collect_defs_children(doc_b.root)
      strip_defs(doc_a.root)
      strip_defs(doc_b.root)

      # Flatten single-child transform groups so
      # `<g transform="M"><X/></g>` ≡ `<X transform="M"/>`.
      flatten_transform_groups(doc_a.root)
      flatten_transform_groups(doc_b.root)

      result = comparator.compare_nodes(doc_a.root, doc_b.root, [])
      return result unless result.equal

      comparator.compare_def_set(defs_a, defs_b, ["<defs>(multiset)"])
    end

    def equal?(svg_a, svg_b, **opts)
      compare(svg_a, svg_b, **opts).equal
    end

    # Internal helpers --------------------------------------------------

    def parse(svg)
      Leptris::XML.parse(svg, options: Leptris::XML::ParseOptions.noblanks)
    end

    def collect_defs_children(root)
      root.css("defs").flat_map(&:element_children)
    end

    def strip_defs(root)
      root.css("defs").each(&:remove)
    end

    # Walk a tree and hoist `<g transform="M"><single_child/></g>` to
    # `<child transform="M_composed"/>`. Mutates the tree in place.
    # Composed transform = M (g) ∘ M' (child's existing transform).
    # Recurses into children after hoisting so nested groups collapse.
    def flatten_transform_groups(node)
      return unless node

      # Recurse depth-first so child transformations compose before
      # parent hoisting. Use a snapshot since we mutate during iteration.
      node.element_children.to_a.each { |c| flatten_transform_groups(c) }

      return unless node.name == "g"
      return unless node.attributes.key?("transform")

      kids = node.element_children
      return unless kids.size == 1

      child = kids.first
      g_transform = node.attributes["transform"].value
      child_transform = child.attributes["transform"]&.value
      merged = compose_transforms(g_transform, child_transform)

      # Set the merged transform directly on the child node.
      # `replace(child)` moves child out of g into g's position in the
      # tree (preserving child's own children).
      if merged && !merged.empty?
        child["transform"] = merged
      else
        child.delete("transform")
      end
      node.replace(child)
    end

    # Compose two SVG transform strings. Returns nil if both nil.
    # Order: applies `outer` AFTER `inner` (matches SVG nesting
    # semantics — the outer wrapper's transform is applied last to
    # child points).
    def compose_transforms(outer, inner)
      return inner if outer.nil? || outer.empty?
      return outer if inner.nil? || inner.empty?

      # Lazy-load — only needed when both sides actually have
      # transforms (rare path).
      require "emf"
      outer_matrix = Svg::TransformParser.parse(outer)
      inner_matrix = Svg::TransformParser.parse(inner)
      composed = Svg::TransformParser.multiply(outer_matrix, inner_matrix)
      format_matrix(composed)
    end

    # Render a Matrix as the SVG `matrix(a b c d e f)` form (canonical
    # representation for comparison).
    def format_matrix(matrix)
      format("matrix(%.4f %.4f %.4f %.4f %.4f %.4f)",
             matrix.m11, matrix.m12, matrix.m21, matrix.m22,
             matrix.dx, matrix.dy)
    end

    # Encapsulated comparator with tolerance state.
    class Comparator
      def initialize(tolerance)
        @tolerance = tolerance
      end

      def compare_nodes(a, b, path)
        return ok if a.nil? && b.nil?
        return fail_at(path, "missing node on one side") if a.nil? || b.nil?
        return fail_at(path, "tag <#{a.name}> vs <#{b.name}>") unless a.name == b.name

        result = compare_attrs(a, b, path)
        return result unless result.equal

        result = compare_text(a, b, path)
        return result unless result.equal

        compare_children(a, b, path)
      end

      def compare_def_set(a_kids, b_kids, path)
        unless a_kids.size == b_kids.size
          return fail_at(path, "child count #{a_kids.size} vs #{b_kids.size}")
        end

        b_pool = b_kids.to_a
        a_kids.each do |x|
          match_idx = b_pool.index { |y| compare_nodes(x, y, path).equal }
          return fail_at(path, "child #{x.name}#{id_label(x)} not matched in B") unless match_idx

          b_pool.delete_at(match_idx)
        end
        ok
      end

      private

      def ok
        Result.new(equal: true)
      end

      def fail_at(path, msg)
        Result.new(equal: false, reason: "#{path.join(' > ')}: #{msg}")
      end

      def compare_attrs(a, b, path)
        keys_a = a.attributes.keys.sort
        keys_b = b.attributes.keys.sort
        unless keys_a == keys_b
          only_a = keys_a - keys_b
          only_b = keys_b - keys_a
          return fail_at(path, "attrs only in A: #{only_a}; only in B: #{only_b}")
        end

        a.attributes.each do |key, attr|
          result = compare_value(attr.value, b.attributes[key].value, path + ["@#{key}"])
          return result unless result.equal
        end

        ok
      end

      def compare_text(a, b, path)
        text_a = a.content.strip
        text_b = b.content.strip
        return ok if text_a == text_b

        return ok if text_a.gsub(/\s+/, " ") == text_b.gsub(/\s+/, " ")

        fail_at(path, "text #{text_a[0, 40].inspect} vs #{text_b[0, 40].inspect}")
      end

      def compare_children(a, b, path)
        a_kids = a.element_children
        b_kids = b.element_children

        unless a_kids.size == b_kids.size
          return fail_at(path, "child count #{a_kids.size} vs #{b_kids.size}")
        end

        a_kids.zip(b_kids).each_with_index do |(x, y), i|
          label = "#{a.name}>#{x.name}[#{i}]"
          result = compare_nodes(x, y, path + [label])
          return result unless result.equal
        end

        ok
      end

      def id_label(elem)
        id = elem.attributes["id"]
        id ? "[##{id.value}]" : ""
      end

      def compare_value(va, vb, path)
        return ok if va == vb

        ca = canonicalise(va)
        cb = canonicalise(vb)
        return ok if ca == cb

        nums_a = extract_numbers(ca)
        nums_b = extract_numbers(cb)
        if nums_a && nums_b && nums_a.size == nums_b.size
          non_num_a = strip_numbers(ca)
          non_num_b = strip_numbers(cb)
          return ok if non_num_a == non_num_b && numbers_match?(nums_a, nums_b)
        end

        fail_at(path, "#{va[0, 60].inspect} vs #{vb[0, 60].inspect}")
      end

      def canonicalise(value)
        result = value.dup
        SvgMatcher::TYPO_NORMALISATIONS.each { |typo, fixn| result.gsub!(typo, fixn) }
        SvgMatcher::ID_REGEXPS.each { |re| result.gsub!(re, "X") }
        result.gsub!(/(\d+(?:\.\d+)?)px\b/, '\1')
        result
      end

      def extract_numbers(str)
        nums = str.to_s.scan(/-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/).map(&:to_f)
        nums.empty? ? nil : nums
      end

      def strip_numbers(str)
        str.to_s.gsub(/-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/i, "N")
      end

      def numbers_match?(a, b)
        a.zip(b).all? do |x, y|
          (x - y).abs < @tolerance
        end
      end
    end
  end
end
