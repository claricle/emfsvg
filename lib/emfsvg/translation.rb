# frozen_string_literal: true

module Emfsvg
  # SVG → EMF translation layer. Consumes Svg::* value objects,
  # produces an Emf::Model::Metafile via wire record construction.
  module Translation
    autoload :EmfRenderer, "emfsvg/translation/emf_renderer"
    autoload :HeaderBuilder, "emfsvg/translation/header_builder"
    autoload :RecordEmitter, "emfsvg/translation/record_emitter"
    autoload :Context, "emfsvg/translation/context"
    autoload :HandlerRegistry, "emfsvg/translation/handler_registry"
    autoload :Handlers, "emfsvg/translation/handlers"
    autoload :Scaler, "emfsvg/translation/scaler"
    autoload :DecimalDetector, "emfsvg/translation/decimal_detector"
    autoload :LocalOrigin, "emfsvg/translation/local_origin"
  end
end
