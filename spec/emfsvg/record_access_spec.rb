# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::RecordAccess do
  let(:records) { Emf::Emr::Binary::Records }
  let(:bytes) { File.binread(File.expand_path("../fixtures/image1.emf", __dir__)) }
  let(:adapters) { Emf.parse(bytes).to_a }

  # A record of an emf without the value API: the wire only.
  let(:legacy) do
    Class.new do
      attr_reader :wire

      def initialize(wire) = @wire = wire
    end
  end

  describe ".wire_class" do
    it "names the class of a parsed record" do
      adapters.each { |adapter| expect(described_class.wire_class(adapter)).to eq(adapter.wire.class) }
    end

    it "falls back to the wire's class without the adapter method" do
      expect(described_class.wire_class(legacy.new(records::SaveDc.new))).to eq(records::SaveDc)
    end
  end

  describe ".fields" do
    it "gives the value view for a record of a value class" do
      adapter = adapters.find { |candidate| described_class::VALUE_CLASSES[candidate.wire.class] }
      skip "emf without the value API" unless adapter.respond_to?(:values)

      expect(described_class.fields(adapter, adapter.wire.class)).to eq(adapter.values)
    end

    it "gives the wire for a class outside the value classes" do
      adapter = adapters.find { |candidate| !described_class::VALUE_CLASSES[candidate.wire.class] }
      expect(described_class.fields(adapter, adapter.wire.class)).to equal(adapter.wire)
    end

    it "gives the wire for a record without the value API" do
      record = legacy.new(records::SaveDc.new)
      expect(described_class.fields(record, records::SaveDc)).to equal(record.wire)
    end
  end

  describe "rendering" do
    it "emits the same SVG from values as from wires" do
      from_values = Emfsvg.from_bytes(bytes)
      stub_const("Emfsvg::RecordAccess::VALUE_CLASSES", {}.compare_by_identity.freeze)
      expect(Emfsvg.from_bytes(bytes)).to eq(from_values)
    end
  end
end
