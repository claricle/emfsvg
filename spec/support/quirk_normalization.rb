# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    # The emf88 gate's canonical quirk equivalence (ported from
    # vectory-rs/crates/emf88-parity/tests/parity_corpus.rs, normalize_quirks):
    # the reference renderer emits whitespace inside the tag grammar that XML
    # parsing discards (extra spaces between attributes, `style ="..."`,
    # space before `/>`), and the SVG model declares those sites
    # non-representable. Both lanes' bytes are therefore compared under the
    # same normalization; quoted attribute values are never touched, so
    # quirks inside values compare byte-for-byte.
    module QuirkNormalization
      module_function

      def normalize(input)
        out = +""
        i = 0
        length = input.length
        while i < length
          if input[i, 9] == "<![CDATA["
            close = input.index("]]>", i)
            return out + input[i..] if close.nil?

            out << input[i...(close + 3)]
            i = close + 3
          elsif input[i, 4] == "<!--"
            close = input.index("-->", i)
            return out + input[i..] if close.nil?

            out << input[i...(close + 3)]
            i = close + 3
          elsif input[i] == "<"
            consumed, normalized = normalize_header(input, i)
            out << normalized
            i += consumed
          else
            out << input[i]
            i += 1
          end
        end
        out
      end

      # Normalizes one markup header: whitespace outside quoted attribute
      # values collapses to a single space, disappears before `=`, `/>`, and
      # `>`. Returns [consumed, normalized].
      def normalize_header(input, start)
        out = +""
        in_quotes = false
        i = start
        limit = input.length
        while i < limit
          ch = input[i]
          if ch == '"'
            in_quotes = !in_quotes
            out << ch
          elsif ch == ">" && !in_quotes
            out << ">"
            return [i + 1 - start, out]
          elsif !in_quotes && whitespace?(ch)
            j = i
            j += 1 while j < limit && whitespace?(input[j])
            rest = input[j..]
            out << " " unless rest.nil? || rest.start_with?("=", "/>", ">")
            i = j
            next
          else
            out << ch
          end
          i += 1
        end
        [limit - start, out]
      end

      def whitespace?(char)
        !char.nil? && char.match?(/\s/)
      end
    end
  end
end
