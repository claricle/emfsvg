# frozen_string_literal: true

module Emfsvg
  # 1-indexed GDI object table (matches EMF's handle numbering).
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
      @entries = [] # 0-indexed internally; EMF indices are 1-based
    end

    def store(index, type, object)
      ensure_capacity(index)
      @entries[index - 1] = Entry.new(type: type, object: object)
    end

    def lookup(index)
      @entries[index - 1]
    end

    def delete(index)
      @entries[index - 1] = nil
    end

    def size
      @entries.compact.size
    end

    private

    def ensure_capacity(index)
      return if @entries.size >= index

      @entries.fill(nil, @entries.size...index)
    end
  end
end
