# frozen_string_literal: true

module Emfsvg
  # SaveDC/RestoreDC stack of DeviceContext snapshots. RestoreDC's argument
  # is relative (negative = pop N levels) or absolute (positive = pop until
  # N levels remain).
  class TransformStack
    def initialize
      @stack = []
    end

    def push(dc)
      @stack.push(dc.dup)
    end

    def restore(saved_dc)
      # Per MS-EMF RestoreDC: if saved_dc < 0, pop that many. If > 0, pop
      # until size == saved_dc.
      if saved_dc.negative?
        saved_dc.abs.times { @stack.pop }
      else
        @stack.pop until @stack.size <= saved_dc
      end
      @stack.last
    end

    def size
      @stack.size
    end
  end
end
