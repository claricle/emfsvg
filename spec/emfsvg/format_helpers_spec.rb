# frozen_string_literal: true

require "spec_helper"

# Specs for Emfsvg::FormatHelpers — C-printf-compatible float formatting.
#
# These specs document the contract that fmt() must produce the same
# output as libemf2svg's C printf("%.4f", v) for any IEEE-754 double,
# including values whose decimal display is a midpoint but whose stored
# bits are slightly above or below (e.g. 459.04375 is stored as
# 459.04374999… and must round to "459.0437", not "459.0438").
RSpec.describe Emfsvg::FormatHelpers do
  describe ".fmt" do
    it "formats a simple integer" do
      expect(described_class.fmt(1)).to eq("1.0000")
    end

    it "formats a fractional value" do
      expect(described_class.fmt(0.5)).to eq("0.5000")
    end

    it "preserves 4 decimal places" do
      expect(described_class.fmt(123.4)).to eq("123.4000")
    end

    it "rounds half-to-even on exact-midpoint doubles" do
      # 4499.03125 is exactly representable as a double → midpoint.
      # C printf rounds to even → "4499.0312".
      expect(described_class.fmt(4499.03125)).to eq("4499.0312")
    end

    it "rounds based on actual stored bits for sub-midpoint display values" do
      # 459.04375 displays as a midpoint but is stored as 459.04374999…
      # C reads the actual bits → "459.0437".
      expect(described_class.fmt(459.04375)).to eq("459.0437")
    end

    it "rounds based on actual stored bits for super-midpoint display values" do
      # 330.70375 displays as a midpoint but is stored as 330.70375000…01
      # → "330.7038".
      expect(described_class.fmt(330.70375)).to eq("330.7038")
    end

    it "handles negative values" do
      expect(described_class.fmt(-459.04375)).to eq("-459.0437")
    end

    it "handles zero" do
      expect(described_class.fmt(0)).to eq("0.0000")
    end

    it "truncates extra decimals" do
      expect(described_class.fmt(1.123456789)).to eq("1.1235")
    end

    it "accepts string input" do
      expect(described_class.fmt("459.04375")).to eq("459.0437")
    end

    it "accepts integer input" do
      expect(described_class.fmt(42)).to eq("42.0000")
    end
  end

  describe ".fmt fast path" do
    # Values near a 4-decimal midpoint, small magnitudes and signs, where
    # naive float rounding disagrees with exact half-even rounding.
    [79_109.58455, -75.41225, 80_042.67505, 66.11065, 0.00005, -0.00005,
     0.00015, -0.00001, 0.99995, -0.0, 1e8 + 0.00005, 2_000_000.5].each do |value|
      it "matches exact decimal rounding for #{value}" do
        expect(described_class.fmt(value))
          .to eq(described_class.fmt_via_decimal(value))
      end
    end

    it "matches exact decimal rounding across random values" do
      rng = Random.new(7)
      values = Array.new(5_000) do
        (rng.rand((-10**9)..(10**9)) / 10_000.0) + [0, 0.00005, 0.00015].sample
      end
      expect(values.reject { |v| described_class.fmt(v) == described_class.fmt_via_decimal(v) })
        .to be_empty
    end
  end

  describe ".fmt_xy" do
    it "formats a coordinate pair with trailing space" do
      expect(described_class.fmt_xy(1.5, 2.5)).to eq("1.5000,2.5000 ")
    end

    it "applies the same rounding as fmt" do
      expect(described_class.fmt_xy(459.04375, 330.70375))
        .to eq("459.0437,330.7038 ")
    end

    it "handles negative coordinates" do
      expect(described_class.fmt_xy(-1.0, -2.0)).to eq("-1.0000,-2.0000 ")
    end
  end

  describe ".append" do
    it "appends the fmt text to the buffer and returns the buffer" do
      buffer = +"x="
      expect(described_class.append(buffer, -12.34567)).to equal(buffer)
      expect(buffer).to eq("x=-12.3457")
    end

    it "matches fmt for ties, zero, negatives and large values" do
      values = [0, -0.0, 0.00005, -0.00005, 459.04375, 99_999.99995, 123_456.5, 1e9, 2.5e12, -7, 3]
      values.each do |value|
        expect(described_class.append(+"", value)).to eq(described_class.fmt(value))
      end
    end
  end

  describe ".append_xy" do
    it "appends the same text fmt_xy returns" do
      buffer = +"M "
      described_class.append_xy(buffer, 1.5, -2.25)
      expect(buffer).to eq("M #{described_class.fmt_xy(1.5, -2.25)}")
    end
  end
end
