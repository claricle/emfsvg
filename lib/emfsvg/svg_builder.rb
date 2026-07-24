# frozen_string_literal: true

module Emfsvg
  # Lightweight XML builder tailored to SVG output. No external dependency.
  # Emits indented XML with explicit attribute ordering.
  class SvgBuilder
    def initialize
      @out = +""
      @indent = 0
    end

    attr_reader :out

    def declaration
      @out << %(<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n)
      self
    end

    def doctype
      @out << %(<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">\n)
      self
    end

    def tag(name, attrs = {}, single: false)
      open_tag(name, attrs, single: single)
      if block_given?
        @indent += 1
        yield
        @indent -= 1
        close_tag(name)
      end
      self
    end

    def text(content)
      @out << indent << escape_text(content) << "\n"
      self
    end

    def raw(string)
      @out << indent << string << "\n"
      self
    end

    def to_s
      @out
    end

    private

    def open_tag(name, attrs, single:)
      @out << indent << "<" << name
      attrs.each do |k, v|
        next if v.nil?

        @out << %( #{k}=") << escape_attr(v.to_s) << '"'
      end
      @out << (single ? " />\n" : ">\n")
    end

    def close_tag(name)
      @out << indent << "</" << name << ">\n"
    end

    def indent
      "  " * @indent
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
