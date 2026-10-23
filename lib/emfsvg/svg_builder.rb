# frozen_string_literal: true

module Emfsvg
  # Lightweight XML builder matching libemf2svg's exact byte output:
  #   - no indentation
  #   - self-closing elements use `/>` (no leading space)
  #   - callers control newlines explicitly via `rawln` / `newline`
  class SvgBuilder
    def initialize(max_output_bytes: Renderer::MAX_OUTPUT_BYTES)
      @max_output_bytes = max_output_bytes
      @out = (+"").force_encoding("ASCII-8BIT")
    end

    attr_reader :out

    def tag(name, attrs = {}, single: false)
      open_tag(name, attrs, single: single)
      if block_given?
        yield
        close_tag(name)
      end
      self
    end

    def text(content)
      append(escape_text(content))
      self
    end

    # Raw append, no newline.
    def raw(string)
      append(string)
      self
    end

    # Raw append with trailing newline.
    def rawln(string)
      append(string)
      append("\n")
      self
    end

    def newline
      append("\n")
      self
    end

    def to_s
      @out
    end

    private

    def open_tag(name, attrs, single:)
      append("<")
      append(name)
      attrs.each do |k, v|
        next if v.nil?

        append(" ")
        append(k.to_s)
        append('="')
        append(escape_attr(v.to_s))
        append('"')
      end
      append(single ? "/>" : ">")
    end

    def close_tag(name)
      append("</")
      append(name)
      append(">")
    end

    def append(string)
      check_budget(string.bytesize)
      @out << string
    end

    def check_budget(additional_bytes)
      actual = @out.bytesize + additional_bytes
      return if actual <= @max_output_bytes

      raise ResourceLimitError.new(resource: :output_bytes, limit: @max_output_bytes, actual: actual)
    end

    def check_escaped_budget(value, attribute: false)
      additional_bytes = value.bytesize + (value.count("&") * 4) + (value.count("<>") * 3)
      additional_bytes += value.count('"') * 5 if attribute
      check_budget(additional_bytes)
    end

    def escape_attr(value)
      check_escaped_budget(value, attribute: true)
      value.gsub("&", "&amp;")
           .gsub("<", "&lt;")
           .gsub(">", "&gt;")
           .gsub('"', "&quot;")
    end

    def escape_text(value)
      check_escaped_budget(value)
      value.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
  end
end
