# frozen_string_literal: true

module Emfsvg
  module Translation
    # Handlers are stateless callables that translate one Svg::Element
    # subclass into EMF records, operating on a Context. They are
    # registered in a HandlerRegistry, keyed by element class.
    module Handlers
      autoload :SharedGdi, "emfsvg/translation/handlers/shared_gdi"
      autoload :RectHandler, "emfsvg/translation/handlers/rect_handler"
      autoload :EllipseHandler, "emfsvg/translation/handlers/ellipse_handler"
      autoload :CircleHandler, "emfsvg/translation/handlers/circle_handler"
      autoload :LineHandler, "emfsvg/translation/handlers/line_handler"
      autoload :PolylineHandler, "emfsvg/translation/handlers/polyline_handler"
      autoload :PolygonHandler, "emfsvg/translation/handlers/polygon_handler"
      autoload :PathHandler, "emfsvg/translation/handlers/path_handler"
      autoload :MappedCircularArc, "emfsvg/translation/handlers/mapped_circular_arc"
      autoload :MappedArc, "emfsvg/translation/handlers/mapped_arc"
      autoload :MappedPie, "emfsvg/translation/handlers/mapped_pie"
      autoload :CircularArc, "emfsvg/translation/handlers/circular_arc"
      autoload :PathFlattener, "emfsvg/translation/handlers/path_flattener"
      autoload :GroupHandler, "emfsvg/translation/handlers/group_handler"
      autoload :TextHandler, "emfsvg/translation/handlers/text_handler"
      autoload :ImageHandler, "emfsvg/translation/handlers/image_handler"
      autoload :DefsHandler, "emfsvg/translation/handlers/defs_handler"
      autoload :ClipPathHandler, "emfsvg/translation/handlers/clip_path_handler"
    end
  end
end
