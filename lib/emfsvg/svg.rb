# frozen_string_literal: true

module Emfsvg
  # Pure SVG domain model. No EMF knowledge lives here.
  #
  # Svg::Parser consumes a leptris-parsed SVG document and produces
  # Svg::Document / Svg::Element value objects. Translation layer
  # (Emfsvg::Translation) consumes these.
  module Svg
    autoload :Document, "emfsvg/svg/document"
    autoload :Element, "emfsvg/svg/element"
    autoload :OpenElement, "emfsvg/svg/element"
    autoload :Parser, "emfsvg/svg/parser"
    autoload :AttributeParser, "emfsvg/svg/attribute_parser"
    autoload :Color, "emfsvg/svg/color"
    autoload :Paint, "emfsvg/svg/paint"
    autoload :Stroke, "emfsvg/svg/stroke"
    autoload :PathData, "emfsvg/svg/path_data"
    autoload :TransformParser, "emfsvg/svg/transform_parser"
    autoload :ClipPathRegistry, "emfsvg/svg/clip_path_registry"
    autoload :Elements, "emfsvg/svg/elements"
  end
end

require "emfsvg/svg/elements"
