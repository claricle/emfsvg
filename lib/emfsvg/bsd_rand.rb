# frozen_string_literal: true

module Emfsvg
  # Replicates BSD rand() (macOS libc default) with default seed 1, which
  # libemf2svg relies on for clip-path IDs via get_id() → rand().
  #
  # The first call returns 16807, then 282475249, 1622650073, ... We pre-load
  # 5000 values from a generated table to keep the runtime trivial. If more
  # are needed, extend the table via `scripts/dump_rand.c`.
  class BsdRand
    SEQUENCE_PATH = File.expand_path("bsd_rand_sequence.txt", __dir__)
    @values = File.readlines(SEQUENCE_PATH, chomp: true).map(&:to_i)
    @index = 0

    class << self
      def next
        v = @values[@index]
        @index += 1
        v
      end

      def reset
        @index = 0
      end

      def values
        @values
      end
    end
  end
end
