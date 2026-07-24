# frozen_string_literal: true

require "emf"

module Emfsvg
  autoload :VERSION, "emfsvg/version"
  autoload :Error, "emfsvg/error"
  autoload :FormatError, "emfsvg/error"
  autoload :RenderError, "emfsvg/error"
  autoload :Renderer, "emfsvg/renderer"
  autoload :DeviceContext, "emfsvg/device_context"
  autoload :ObjectTable, "emfsvg/object_table"
  autoload :TransformStack, "emfsvg/transform_stack"
  autoload :SvgBuilder, "emfsvg/svg_builder"
  autoload :Options, "emfsvg/options"

  class << self
    # Render an Emf::Model::Metafile to an SVG string.
    #
    # Options:
    #   namespace:  XML namespace prefix, e.g. "svg" (default: none)
    #   width:      override viewport width (default: from metafile header)
    #   height:     override viewport height
    #   verbose:    print record-by-record dispatch to STDERR (default: false)
    #   emf_plus:   attempt to render EMF+ records instead of EMF fallback
    #               (default: false — EMF+ is structured-parsed by emf but
    #               not yet rendered)
    def to_svg(metafile, **options)
      Renderer.call(metafile, Options.new(**options))
    end

    # Parse from bytes then render.
    def from_bytes(bytes, **options)
      to_svg(Emf.parse(bytes), **options)
    end

    # Parse from a file path then render.
    def from_file(path, **options)
      from_bytes(File.read(path, mode: "rb"), **options)
    end
  end
end
