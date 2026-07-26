# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::Translation::Scaler::Identity do
  it "truncates decimal to int" do
    expect(described_class.new.to_int(3.7)).to eq(3)
    expect(described_class.new.to_int(-2.3)).to eq(-2)
  end

  it "passes integers unchanged" do
    expect(described_class.new.to_int(42)).to eq(42)
  end

  it "has factor 1" do
    expect(described_class.new.factor).to eq(1)
  end

  it "is not scaled" do
    expect(described_class.new).not_to be_scaled
  end
end

RSpec.describe Emfsvg::Translation::Scaler::Fixed do
  it "multiplies by factor (default 10000)" do
    expect(described_class.new.to_int(1.5)).to eq(15_000)
    expect(described_class.new.to_int(0.0001)).to eq(1)
  end

  it "rounds to nearest integer" do
    expect(described_class.new.to_int(1.23456)).to eq(12_346)
  end

  it "has factor 10000 by default" do
    expect(described_class.new.factor).to eq(10_000)
  end

  it "is scaled" do
    expect(described_class.new).to be_scaled
  end

  it "detects unsafe values that would overflow int32" do
    scaler = described_class.new
    expect(scaler.unsafe?(300_000)).to be true
    expect(scaler.unsafe?(100_000)).to be false
  end
end
