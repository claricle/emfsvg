# frozen_string_literal: true

module Emfsvg
  # SaveDC/RestoreDC stack of DeviceContext snapshots.
  #
  # IMPORTANT: libemf2svg's restoreDeviceContext WALKS the stack to find the
  # target level but does NOT remove entries — the same save can be restored
  # multiple times. This mirrors Windows GDI behavior where RestoreDC's
  # saved_dc argument identifies a level (not a one-shot pop). We replicate
  # that exactly: restore() reads the target snapshot but leaves the stack
  # intact.
  class TransformStack
    def initialize
      @stack = []
    end

    def push(dc)
      @stack.push(dc.dup)
    end

    # Returns the snapshot at the target level. The stack is NOT modified.
    # saved_dc semantics match libemf2svg: negative N = "N levels back from
    # the top" (so -1 is the top, -2 is one below, etc.); positive N is
    # treated as the equivalent 1-based absolute level.
    def restore(saved_dc)
      target_index = if saved_dc.negative?
                       @stack.size + saved_dc
                     else
                       saved_dc - 1
                     end
      return nil if target_index.negative? || target_index >= @stack.size

      @stack[target_index]
    end

    def size
      @stack.size
    end
  end
end
