# frozen_string_literal: true

module Emfsvg
  # GDI object table keyed by EMF handles.
  # SELECTOBJECT copies from the table into the current DeviceContext.
  # DELETEOBJECT removes the slot.
  class ObjectTable
    Entry = Struct.new(:type, :object, keyword_init: true) do
      def pen?
        type == :pen
      end

      def brush?
        type == :brush
      end

      def font?
        type == :font
      end
    end

    def initialize
      @entries = {}
    end

    def store(index, type, object)
      @entries[index] = Entry.new(type: type, object: object)
    end

    def lookup(index)
      @entries[index]
    end

    def delete(index)
      @entries.delete(index)
      nil
    end

    def size
      @entries.size
    end
  end
end
