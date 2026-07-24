# frozen_string_literal: true

module Emfsvg
  autoload :Visitors, "emfsvg/visitors"

  # Top-level renderer: walks an Emf::Model::Metafile and emits an SVG
  # string via SvgBuilder.
  #
  # Matches the exact SVG structure of libemf2svg:
  #   1. XML declaration
  #   2. <svg version="1.1" ... width="W.0000" height="H.0000">
  #   3. <g transform="translate(-RefX, -RefY)">  (header translate)
  #   4. ... content with per-element point_cal coordinate transform ...
  #   5. </g>  (close world transform if open)
  #   6. </g>  (close header translate)
  #   7. </svg>
  class Renderer
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
      BsdRand.reset
      compute_header_params
    end

    def call
      emit_xml_declaration
      emit_svg_open do
        emit_header_translate_group do
          visit_records
          # Close any open world transform groups
          @builder.raw("</g>" * @open_groups) if @open_groups.positive?
        end
      end
      result = @builder.to_s
      raise RenderError, "SVG output exceeds #{MAX_OUTPUT_BYTES} bytes" if result.bytesize > MAX_OUTPUT_BYTES

      result
    end

    private

    attr_reader :scaling, :ref_x, :ref_y, :fix_broken_y, :px_per_mm, :img_width, :img_height

    def compute_header_params
      b = @metafile.header.bounds
      @fix_broken_y = (b.top * b.bottom).negative?

      ratio_xy = (b.right - b.left).to_f / (b.bottom - b.top)

      if @options.width && @options.height
        @img_width = @options.width.to_f
        @img_height = @options.height.to_f
        tmp_w = @img_height * ratio_xy
        if tmp_w > @img_width
          @img_height = @img_width / ratio_xy
        else
          @img_width = tmp_w
        end
      elsif @options.height
        @img_height = @options.height.to_f
        @img_width = @img_height * ratio_xy
      elsif @options.width
        @img_width = @options.width.to_f
        @img_height = @img_width / ratio_xy
      else
        @img_width = (b.right - b.left).abs.to_f
        @img_height = (b.bottom - b.top).abs.to_f
      end

      bounds_width = (b.right - b.left).abs
      @scaling = bounds_width.zero? ? 1.0 : @img_width / bounds_width.to_f
      @ref_x = b.left.to_f
      @ref_y = b.top.to_f

      dev = @metafile.header.device_pixels
      mm = @metafile.header.device_mm
      @px_per_mm = mm.cx.zero? ? 1.0 : dev.cx.to_f / mm.cx

      @open_groups = 0
    end

    def emit_xml_declaration
      @builder.rawln('<?xml version="1.0"  encoding="UTF-8" standalone="no"?>')
    end

    def emit_svg_open(&)
      w = format("%.4f", @img_width)
      h = format("%.4f", @img_height)
      if @fix_broken_y
        w = format("%.4f", @img_width + 1)
        h = format("%.4f", @img_height + 1)
      end
      attrs = {
        "version" => "1.1",
        "xmlns" => "http://www.w3.org/2000/svg",
        "xmlns:xlink" => "http://www.w3.org/1999/xlink",
        "width" => w,
        "height" => h
      }
      attrs["xmlns:svg"] = "http://www.w3.org/2000/svg" if @options.namespace == "svg"
      @builder.raw("<")
      @builder.raw("svg")
      attrs.each do |k, v|
        @builder.raw(" #{k}=\"#{v}\"")
      end
      @builder.rawln(">")
      yield
      @builder.rawln("</svg>")
    end

    def emit_header_translate_group
      if @fix_broken_y
        # Match libemf2svg's literal "0.00 00" (typo in the C source).
        @builder.rawln('<g transform="translate(0.0000, 0.00 00)">')
      else
        tx = format("%.4f", -1.0 * @ref_x * @scaling)
        ty = format("%.4f", -1.0 * @ref_y * @scaling)
        @builder.rawln("<g transform=\"translate(#{tx}, #{ty})\">")
      end
      yield
      @builder.rawln("</g>")
    end

    def visit_records
      records = @metafile.to_a
      path_actions = build_path_action_map(records)
      visitor = Visitors::EmrVisitor.new(
        @builder, @dc, @object_table, @transform_stack,
        @metafile.header.bounds, @fix_broken_y, @options,
        scaling: @scaling, ref_x: @ref_x, ref_y: @ref_y,
        px_per_mm: @px_per_mm,
        path_actions: path_actions
      )
      records.each_with_index do |record, idx|
        visitor.current_record_idx = idx
        record.accept(visitor)
      end
      visitor.flush_open_groups
      @open_groups = visitor.open_group_count
    end

    # Pre-scan records to build a map of { begin_path_index => action }
    # where action is :fill, :stroke, :stroke_fill, :end, or :abort.
    # This mirrors libemf2svg's two-pass pathStack analysis.
    def build_path_action_map(records)
      map = {}
      records.each_with_index do |r, i|
        wire = r.wire
        case wire.class.name.split("::").last
        when "BeginPath"
          # Find the next EndPath, FillPath, StrokePath, StrokeAndFillPath, or AbortPath
          action = :end
          ((i + 1)...records.size).each do |j|
            name = records[j].wire.class.name.split("::").last
            case name
            when "EndPath"
              # EndPath is followed by FillPath/StrokePath/StrokeAndFillPath in
              # practice — keep scanning to find which.
              next
            when "FillPath"
              action = :fill
              break
            when "StrokePath"
              action = :stroke
              break
            when "StrokeAndFillPath"
              action = :stroke_fill
              break
            when "AbortPath"
              action = :abort
              break
            when "BeginPath"
              # Nested path — unusual; treat as default
              break
            end
          end
          map[i] = action
        end
      end
      map
    end
  end
end
