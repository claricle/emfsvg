# frozen_string_literal: true

require "emf"

module Emfsvg
  module Translation
    # Top-level orchestrator: takes an Svg::Document, walks its element
    # tree via a HandlerRegistry, and produces an Emf::Model::Metafile
    # whose serialized bytes can be re-parsed by Emf.parse and
    # re-rendered by Emfsvg.from_bytes.
    #
    # The default registry maps the supported SVG element vocabulary
    # (rect, ellipse, circle, line, polyline, polygon, path, group,
    # text, image, defs, clipPath) to handler classes.
    #
    # If the SVG contains any decimal coordinates, the renderer installs
    # `Scaler::Fixed` (multiplies coords by 10_000 to preserve 4
    # decimal places in EMF int32 fields) and emits SetMapMode +
    # SetWindowExtEx + SetViewportExtEx so emfsvg's renderer computes
    # the matching `sf_x = 1/10_000`.
    class EmfRenderer
      DEFAULT_REGISTRY = HandlerRegistry.new

      def self.call(document, registry: DEFAULT_REGISTRY)
        new(document, registry: registry).call
      rescue Scaler::Fixed::Overflow
        # Derived bounds and relative path points may exceed the source values.
        # Rebuild the entire record stream in the original unscaled coordinates.
        new(document, registry: registry, scaler: Scaler::Identity.new).call
      end

      def self.register_default_handlers!
        DEFAULT_REGISTRY.register(Svg::Elements::Rect, Handlers::RectHandler)
        DEFAULT_REGISTRY.register(Svg::Elements::Ellipse, Handlers::EllipseHandler)
        DEFAULT_REGISTRY.register(Svg::Elements::Circle, Handlers::CircleHandler)
        DEFAULT_REGISTRY.register(Svg::Elements::Line, Handlers::LineHandler)
        DEFAULT_REGISTRY.register(Svg::Elements::Polyline, Handlers::PolylineHandler)
        DEFAULT_REGISTRY.register(Svg::Elements::Polygon, Handlers::PolygonHandler)
        DEFAULT_REGISTRY.register(Svg::Elements::Path, Handlers::PathHandler)
        DEFAULT_REGISTRY.register(Svg::Elements::Group, Handlers::GroupHandler)
        DEFAULT_REGISTRY.register(Svg::Elements::Text, Handlers::TextHandler)
        DEFAULT_REGISTRY.register(Svg::Elements::Image, Handlers::ImageHandler)
        DEFAULT_REGISTRY.register(Svg::Elements::Defs, Handlers::DefsHandler)
        DEFAULT_REGISTRY.register(Svg::Elements::ClipPath, Handlers::ClipPathHandler)
      end

      def initialize(document, registry: DEFAULT_REGISTRY, scaler: nil)
        @document = document
        @registry = registry
        @scaler = scaler || pick_scaler
        @context = Context.new(
          handler_registry: registry,
          clip_path_registry: Svg::ClipPathRegistry.from_document(document),
          scaler: @scaler
        )
      end

      def call
        emit_scaling_prelude if @scaler.scaled?
        dispatch_root(@document.root_element)
        emit_eof
        header = HeaderBuilder.build(@document,
                                     n_records: @context.records.size + 1,
                                     n_handles: @context.handle_table_size)
        Emf::Model::Metafile.new(
          format: :emf,
          header: header,
          records: @context.records.freeze
        )
      end

      private

      # Preserve decimal coordinates and explicit cosmetic 1px pens when
      # every scaled coordinate fits an int32.
      def pick_scaler
        fixed = Scaler::Fixed.new
        if DecimalDetector.needs_scaling?(@document) && DecimalDetector.safe_for_fixed_scale?(@document, fixed)
          fixed
        else
          Scaler::Identity.new
        end
      end

      # Emit SetMapMode(ANISOTROPIC) + SetWindowExtEx + SetViewportExtEx
      # so emfsvg's renderer computes sf_x = 1/10_000 = 0.0001 and
      # divides our scaled int coords back to the original decimal.
      def emit_scaling_prelude
        factor = @scaler.factor
        @context.emit(Emf::Emr::Binary::Records::SetMapMode,
                      i_type: Emf::Emr::Binary::TypeCodes::SETMAPMODE,
                      map_mode: 8) # MM_ANISOTROPIC
        @context.emit(Emf::Emr::Binary::Records::SetWindowExtEx,
                      i_type: Emf::Emr::Binary::TypeCodes::SETWINDOWEXTEX,
                      extent: Emf::Binary::Types::SizeL.new(cx: factor, cy: factor))
        @context.emit(Emf::Emr::Binary::Records::SetViewportExtEx,
                      i_type: Emf::Emr::Binary::TypeCodes::SETVIEWPORTEXTEX,
                      extent: Emf::Binary::Types::SizeL.new(cx: 1, cy: 1))
      end

      def dispatch_root(root)
        return unless root

        header_group = @document.header_translate_group
        if header_group
          header_group.children.each { |c| dispatch(c) }
        else
          root.children.each { |c| dispatch(c) }
        end
      end

      def dispatch(element)
        return unless element

        handler = @registry.handler_for(element)
        return descend(element) unless handler

        handler.call(element, @context)
        descend(element) if descend_after_handler?(handler)
      end

      # GroupHandler walks its own children. DefsHandler and
      # ClipPathHandler must NOT descend. Other handlers descend
      # (harmless for leaf elements).
      def descend_after_handler?(handler)
        return false if handler == Handlers::GroupHandler
        return false if handler == Handlers::DefsHandler
        return false if handler == Handlers::ClipPathHandler

        true
      end

      def descend(element)
        element.children.each { |c| dispatch(c) }
      end

      def emit_eof
        @context.emit(Emf::Emr::Binary::Records::Eof,
                      i_type: Emf::Emr::Binary::TypeCodes::EOF,
                      n_size: 20,
                      n_pal_entries: 0,
                      off_pal_entries: 16,
                      n_size_last: 20,
                      body: "")
      end

      register_default_handlers!
    end
  end
end
