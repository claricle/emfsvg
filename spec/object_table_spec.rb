# frozen_string_literal: true

require "spec_helper"
require "emfsvg/device_context"

RSpec.describe Emfsvg::ObjectTable do
  subject(:table) { described_class.new }

  it "starts empty and leaves absent handles empty" do
    expect(table.size).to eq(0)
    expect(table.lookup(1)).to be_nil
    expect(table.lookup(0x8900_0001)).to be_nil
  end

  it "stores large sparse handles without allocating intervening slots" do
    pen = Emfsvg::Pen.new
    table.store(0x8900_0001, :pen, pen)

    expect(table.lookup(0x8900_0001).object).to equal(pen)
    expect(table.lookup(0x8900_0001)).to be_pen
    expect(table.lookup(1)).to be_nil
    expect(table.size).to eq(1)
  end

  it "deletes an absent large handle without adding an entry" do
    expect(table.delete(0x8900_0001)).to be_nil
    expect(table.size).to eq(0)
  end

  it "replaces an existing handle without increasing the size" do
    table.store(3, :pen, Emfsvg::Pen.new)
    brush = Emfsvg::Brush.new
    table.store(3, :brush, brush)

    expect(table.lookup(3).object).to equal(brush)
    expect(table.lookup(3)).to be_brush
    expect(table.size).to eq(1)
  end

  it "deletes a large handle while preserving other entries" do
    pen = Emfsvg::Pen.new
    table.store(1, :pen, pen)
    table.store(0x8900_0001, :brush, Emfsvg::Brush.new)

    expect(table.delete(0x8900_0001)).to be_nil
    expect(table.lookup(0x8900_0001)).to be_nil
    expect(table.lookup(1).object).to equal(pen)
    expect(table.size).to eq(1)
  end
end
