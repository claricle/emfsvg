# frozen_string_literal: true

module Emfsvg
  autoload :Visitors, "emfsvg/visitors"

  # Top-level renderer: walks an Emf::Model::Metafile and emits an SVG
  # string via SvgBuilder.
  #
  # The renderer is the entry point. Dispatching to per-record handlers
  # is delegated to Visitors::EmrVisitor; this class focuses on:
  #   - computing the viewport (header bounds, device dims)
  #   - setting up coordinate transforms (MM_TEXT default)
  #   - opening the root <svg> with proper attributes
  #   - applying the Sparx/Wine Y-repair heuristic when bounds demand it
  class Renderer
    # Refuse to emit more than 500 MB of SVG. Catches accidental blow-ups
    # from corrupt or pathological inputs before the caller runs out of RAM.
    MAX_OUTPUT_BYTES = 500 * 1024 * 1024

    def self.call(metafile, options)
      new(metafile, options).call
    end

    def initialize(metafile, options)
      @metafile = metafile
      @options = options
      @builder = SvgBuilder.new
      @dc = DeviceContext.new
      @object_table = ObjectTable.new
      @transform_stack = TransformStack.new
      @fix_broken_y_transform = should_fix_y_transform?
    end

    def call
      emit_header
      emit_open_svg do
        emit_wine_transform_maybe do
          visit_records
        end
      end
      result = @builder.to_s
      raise RenderError, "SVG output exceeds #{MAX_OUTPUT_BYTES} bytes" if result.bytesize > MAX_OUTPUT_BYTES

      result
    end

    private

    def emit_header
      @builder.declaration
    end

    def viewport_bounds
      @metafile.header.bounds
    end

    def viewport_width
      return @options.width if @options.width

      b = viewport_bounds
      b.right - b.left
    end

    def viewport_height
      return @options.height if @options.height

      b = viewport_bounds
      b.bottom - b.top
    end

    def emit_open_svg(&)
      attrs = {
        "xmlns" => "http://www.w3.org/2000/svg",
        "xmlns:xlink" => "http://www.w3.org/1999/xlink",
        "width" => viewport_width,
        "height" => viewport_height,
        "viewBox" => "#{viewport_bounds.left} #{viewport_bounds.top} #{viewport_width} #{viewport_height}",
        "version" => "1.1"
      }
      attrs["xmlns:svg"] = "http://www.w3.org/2000/svg" if @options.namespace == "svg"
      @builder.tag("svg", attrs, &)
    end

    # Sparx Enterprise Architect under Wine emits EMFs whose complex
    # sub-objects have only the Y anchor negated. Detect via the
    # libemf2svg heuristic: rclBounds.top * rclBounds.bottom < 0.
    def should_fix_y_transform?
      b = viewport_bounds
      (b.top * b.bottom).negative?
    end

    def emit_wine_transform_maybe
      if @fix_broken_y_transform
        # The repair is applied per-element, not as a single mirror.
        # Emit a comment marker so consumers know.
        @builder.raw("<!-- Wine/Sparx Y-repair: top=#{viewport_bounds.top} bottom=#{viewport_bounds.bottom} -->")
      end
      yield
    end

    def visit_records
      visitor = Visitors::EmrVisitor.new(@builder, @dc, @object_table, @transform_stack,
                                         viewport_bounds, @fix_broken_y_transform, @options)
      @metafile.each { |record| record.accept(visitor) }
      visitor.flush_open_groups
    end
  end
end
