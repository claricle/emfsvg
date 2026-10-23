# frozen_string_literal: true

module Emfsvg
  class Error < StandardError; end

  class FormatError < Error; end

  class ParseError < Error; end

  class RenderError < Error; end

  class ResourceLimitError < Error
    attr_reader :resource, :limit, :actual

    def initialize(resource:, limit:, actual:)
      @resource = resource
      @limit = limit
      @actual = actual
      super("#{resource} limit exceeded (#{actual} > #{limit})")
    end
  end
end
