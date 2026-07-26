# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::Translation::Context do
  let(:registry) { Emfsvg::Translation::HandlerRegistry.new }

  it "starts with a fresh DeviceContext, ObjectTable, TransformStack, RecordEmitter" do
    context = described_class.new(handler_registry: registry)
    expect(context.device_context).to be_a(Emfsvg::DeviceContext)
    expect(context.object_table).to be_a(Emfsvg::ObjectTable)
    expect(context.transform_stack).to be_a(Emfsvg::TransformStack)
    expect(context.emitter).to be_a(Emfsvg::Translation::RecordEmitter)
  end

  it "allocates 1-indexed handles monotonically" do
    context = described_class.new(handler_registry: registry)
    expect(context.allocate_handle).to eq(1)
    expect(context.allocate_handle).to eq(2)
    expect(context.allocate_handle).to eq(3)
  end

  it "delegates emit to the RecordEmitter" do
    context = described_class.new(handler_registry: registry)
    context.emit(Emf::Emr::Binary::Records::Eof,
                 i_type: Emf::Emr::Binary::TypeCodes::EOF,
                 n_size: 20, n_pal_entries: 0, off_pal_entries: 16,
                 n_size_last: 20, body: "")
    expect(context.records.size).to eq(1)
  end
end

RSpec.describe Emfsvg::Translation::HandlerRegistry do
  let(:element_class) { Class.new(Emfsvg::Svg::Element) }
  let(:handler) { Class.new { def self.call(*); end } }

  it "looks up by exact element class" do
    registry = described_class.new
    registry.register(element_class, handler)
    expect(registry.handler_for(element_class.new)).to eq(handler)
  end

  it "walks the superclass chain if exact class is not registered" do
    subclass = Class.new(element_class)
    registry = described_class.new
    registry.register(element_class, handler)
    expect(registry.handler_for(subclass.new)).to eq(handler)
  end

  it "returns nil for unregistered element classes" do
    registry = described_class.new
    expect(registry.handler_for(element_class.new)).to be_nil
  end
end

RSpec.describe Emfsvg::Translation::RecordEmitter do
  it "builds a wire record with computed n_size" do
    emitter = described_class.new
    record = emitter.emit(Emf::Emr::Binary::Records::Eof,
                          i_type: Emf::Emr::Binary::TypeCodes::EOF,
                          n_size: 20, n_pal_entries: 0, off_pal_entries: 16,
                          n_size_last: 20, body: "")
    expect(record).to be_a(Emf::Model::Emr::Records::WireAdapter)
    expect(record.wire.n_size).to eq(20)
    expect(record.wire.to_binary_s.bytesize).to eq(20)
  end
end
