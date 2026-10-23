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
        @resolved = {}
      end

      def register(element_class, handler)
        @resolved.clear
        @handlers[element_class] = handler
      end

      # Elements of one class share a handler, so each class is resolved
      # (walking its ancestry) once, until the next registration.
      def handler_for(element)
        klass = element.class
        @resolved.fetch(klass) { @resolved[klass] = resolve(klass) }
      end

      def translate(element, context)
        handler = handler_for(element)
        return unless handler

        handler.call(element, context)
      end

      private

      def resolve(klass)
        while klass
          return @handlers[klass] if @handlers.key?(klass)

          klass = klass.superclass
        end
        nil
      end
    end
  end
end
