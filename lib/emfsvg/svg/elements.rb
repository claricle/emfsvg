# frozen_string_literal: true

module Emfsvg
  module Svg
    # Subclasses of Svg::Element for the supported SVG shape vocabulary.
    # Each subclass parses its typed attributes at construction time
    # (no Nokogiri node is retained). Register in Svg::Element's
    # registry so Svg::Element.from_node dispatches correctly.
    module Elements
      autoload :Stylable, "emfsvg/svg/elements/stylable"
      autoload :Rect, "emfsvg/svg/elements/rect"
      autoload :Circle, "emfsvg/svg/elements/circle"
      autoload :Ellipse, "emfsvg/svg/elements/ellipse"
      autoload :Line, "emfsvg/svg/elements/line"
      autoload :Polyline, "emfsvg/svg/elements/polyline"
      autoload :Polygon, "emfsvg/svg/elements/polygon"
      autoload :Path, "emfsvg/svg/elements/path"
      autoload :Group, "emfsvg/svg/elements/group"
      autoload :Defs, "emfsvg/svg/elements/defs"
      autoload :ClipPath, "emfsvg/svg/elements/clip_path"
      autoload :Text, "emfsvg/svg/elements/text"
      autoload :Image, "emfsvg/svg/elements/image"
    end
  end
end

# Eager-load element subclasses so they register with Svg::Element at
# require time. The registry dispatch (Svg::Element.for) relies on all
# subclasses having called Element.register() by the time parsing starts.
require "emfsvg/svg/elements/stylable"
require "emfsvg/svg/elements/rect"
require "emfsvg/svg/elements/circle"
require "emfsvg/svg/elements/ellipse"
require "emfsvg/svg/elements/line"
require "emfsvg/svg/elements/polyline"
require "emfsvg/svg/elements/polygon"
require "emfsvg/svg/elements/path"
require "emfsvg/svg/elements/group"
require "emfsvg/svg/elements/defs"
require "emfsvg/svg/elements/clip_path"
require "emfsvg/svg/elements/text"
require "emfsvg/svg/elements/image"
