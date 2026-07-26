# frozen_string_literal: true

module Emfsvg
  module Translation
    # Maps SVG element class -> handler class. Handlers implement
    # `.call(element, context)` which appends records to the context's
    # emitter.
    #
    # OCP: adding a new SVG element type means writing a new handler
    # class and registering it. No existing handler code changes.
    class HandlerRegistry
      def initialize
        @handlers = {}
      end

      def register(element_class, handler)
        @handlers[element_class] = handler
      end

      def handler_for(element)
        klass = element.class
        while klass
          return @handlers[klass] if @handlers.key?(klass)

          klass = klass.superclass
        end
        nil
      end

      def translate(element, context)
        handler = handler_for(element)
        return unless handler

        handler.call(element, context)
      end
    end
  end
end
