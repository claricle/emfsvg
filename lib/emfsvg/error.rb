# frozen_string_literal: true

module Emfsvg
  class Error < StandardError; end

  class FormatError < Error; end

  class ParseError < Error; end

  class RenderError < Error; end
end
