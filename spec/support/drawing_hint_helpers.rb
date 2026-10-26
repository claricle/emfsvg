# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    module DrawingHintHelpers
      def comment_wire(payload, length = payload.bytesize)
        padding = (4 - (payload.bytesize % 4)) % 4
        padded = payload + ("\0" * padding)
        Struct.new(:cb_data, :data).new(length, padded)
      end

      def record_spans(bytes)
        offset = bytes.byteslice(4, 4).unpack1("V")
        spans = []
        while offset < bytes.bytesize
          size = bytes.byteslice(offset + 4, 4).unpack1("V")
          spans << [offset, size, bytes.byteslice(offset, 4).unpack1("V")]
          offset += size
        end
        spans
      end
    end
  end
end
