# frozen_string_literal: true

require "emf"

module Emfsvg
  autoload :VERSION, "emfsvg/version"
  autoload :Error, "emfsvg/error"
  autoload :FormatError, "emfsvg/error"
  autoload :ParseError, "emfsvg/error"
  autoload :RenderError, "emfsvg/error"
  autoload :Renderer, "emfsvg/renderer"
  autoload :DeviceContext, "emfsvg/device_context"
  autoload :ObjectTable, "emfsvg/object_table"
  autoload :TransformStack, "emfsvg/transform_stack"
  autoload :SvgBuilder, "emfsvg/svg_builder"
  autoload :Options, "emfsvg/options"
  autoload :DibDecoder, "emfsvg/dib_decoder"
  autoload :PngEncoder, "emfsvg/png_encoder"
  autoload :ClipRegion, "emfsvg/clip_region"
  autoload :BsdRand, "emfsvg/bsd_rand"
  autoload :FormatHelpers, "emfsvg/format_helpers"
  autoload :GlyphIndexMapper, "emfsvg/glyph_index_mapper"
  autoload :PngDecoder, "emfsvg/png_decoder"
  autoload :DibEncoder, "emfsvg/dib_encoder"
  autoload :Svg, "emfsvg/svg"
  autoload :Translation, "emfsvg/translation"
  autoload :RecordAccess, "emfsvg/record_access"

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
      to_svg(parse_metafile(bytes), **options)
    end

    # Parse from a file path then render.
    def from_file(path, **options)
      from_bytes(File.binread(path), **options)
    end

    # Translate an Svg::Document to EMF bytes.
    def to_emf(document)
      metafile = Translation::EmfRenderer.call(document)
      Emf.serialize(metafile)
    end

    # Parse SVG string and translate to EMF bytes.
    def from_svg(svg_string)
      to_emf(Svg::Parser.call(svg_string))
    end

    # Parse SVG from a file path and translate to EMF bytes.
    def from_svg_file(path)
      from_svg(File.read(path))
    end

    private

    def parse_metafile(bytes)
      Emf.parse(bytes)
    rescue Emf::FormatError, Emf::ParseError => e
      raise ParseError, e.message, cause: e
    end
  end
end
