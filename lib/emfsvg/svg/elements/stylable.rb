# frozen_string_literal: true

module Emfsvg
  module Svg
    module Elements
      # Common presentation attribute parsing shared by every shape.
      # Module function — call as `Stylable.parse_style(node)` from
      # an Element subclass's `.from_node` factory.
      #
      # Paint and Stroke are immutable value objects, and a drawing repeats
      # a handful of distinct fill/stroke combinations across thousands of
      # elements, so one instance per distinct attribute set is shared
      # instead of parsing and allocating the same objects for every
      # element.
      module Stylable
        # Distinct attribute sets remembered; past this, parsing falls back
        # to building a fresh pair, so a hostile document cannot grow it.
        PAINT_CACHE_LIMIT = 1024
        PAINT_CACHE_LOCK = Mutex.new
        private_constant :PAINT_CACHE_LOCK, :PAINT_CACHE_LIMIT

        @paint_cache = {}

        module_function

        def parse_style(node)
          fill, stroke = paints(
            node["fill"], node["stroke"], node["stroke-width"],
            node["stroke-dasharray"], node["stroke-linecap"], node["stroke-linejoin"]
          )
          { fill: fill, stroke: stroke, clip_path: node["clip-path"] }
        end

        def paints(fill, stroke, width, dash_array, line_cap, line_join)
          key = [fill, stroke, width, dash_array, line_cap, line_join]
          @paint_cache.fetch(key) do
            pair = [
              Svg::Paint.from_fill(fill),
              Svg::Stroke.parse(stroke: stroke, width: width, dash_array: dash_array,
                                line_cap: line_cap, line_join: line_join)
            ].freeze
            remember(key.freeze, pair)
          end
        end

        def remember(key, pair)
          PAINT_CACHE_LOCK.synchronize do
            @paint_cache[key] = pair if @paint_cache.size < PAINT_CACHE_LIMIT
          end
          pair
        end
      end
    end
  end
end
