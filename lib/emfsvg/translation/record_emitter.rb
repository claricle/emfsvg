# frozen_string_literal: true

require "emf"

module Emfsvg
  module Translation
    # Builds and collects Emf::Model::Emr::Records::WireAdapter instances.
    # Each wire record class (Emf::Emr::Binary::Records::*) is constructed
    # via keyword args; the emitter assigns i_type and computes n_size
    # from the resulting binary length.
    #
    # The emitter is the only place that knows how to construct wire
    # records — handlers call emitter.build_record(klass, **attrs) and
    # don't need to manage i_type / n_size / wrapping themselves.
    class RecordEmitter
      def initialize
        @records = []
      end

      attr_reader :records

      def emit(wire_class, attrs)
        record = build(wire_class, attrs)
        @records << record
        record
      end

      # Construct without appending. Useful for inline inspection in tests.
      def build(wire_class, attrs)
        adapter = Emf::Model::Emr::Records::WireAdapter
        return adapter.build(wire_class, **attrs) if adapter.respond_to?(:build)

        wire = wire_class.new(**attrs)
        wire.n_size = wire.num_bytes
        adapter.new(wire: wire)
      end
    end
  end
end
