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
      # Save a copy; the caller keeps mutating its own @dc reference.
      @stack.push(dc.dup)
    end

    # Returns the snapshot at the target level (which becomes the new
    # post-restore current state). The snapshot is REMOVED from the stack
    # (RestoreDC consumes the saved state per MS-WMF).
    def restore(saved_dc)
      target_index = if saved_dc.negative?
                       @stack.size - saved_dc.abs
                     else
                       saved_dc - 1
                     end
      target_index = 0 if target_index.negative?
      return nil if target_index >= @stack.size || target_index.negative?

      snapshot = @stack[target_index]
      # Drop everything from target_index upward (those saves are discarded).
      @stack = @stack[0...target_index]
      snapshot
    end

    def size
      @stack.size
    end
  end
end
