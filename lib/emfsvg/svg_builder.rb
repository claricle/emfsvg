# frozen_string_literal: true

module Emfsvg
  # Lightweight XML builder matching libemf2svg's exact byte output:
  #   - no indentation
  #   - self-closing elements use `/>` (no leading space)
  #   - callers control newlines explicitly via `rawln` / `newline`
  class SvgBuilder
    def initialize
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
      @out << escape_text(content)
      self
    end

    # Raw append, no newline.
    def raw(string)
      @out << string
      self
    end

    # Raw append with trailing newline.
    def rawln(string)
      @out << string << "\n"
      self
    end

    def newline
      @out << "\n"
      self
    end

    def to_s
      @out
    end

    private

    def open_tag(name, attrs, single:)
      @out << "<" << name
      attrs.each do |k, v|
        next if v.nil?

        @out << " " << k.to_s << '="' << escape_attr(v.to_s) << '"'
      end
      @out << (single ? "/>" : ">")
    end

    def close_tag(name)
      @out << "</" << name << ">"
    end

    def escape_attr(value)
      value.gsub("&", "&amp;")
           .gsub("<", "&lt;")
           .gsub(">", "&gt;")
           .gsub('"', "&quot;")
    end

    def escape_text(value)
      value.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
  end
end
