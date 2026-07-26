# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::Svg::PathData::Parser do
  def parse(str)
    described_class.parse(str)
  end

  def cmd(letter, *args)
    Emfsvg::Svg::PathData::Command.new(letter: letter, args: args)
  end

  it "returns an empty list for nil or blank input" do
    expect(parse(nil)).to eq([])
    expect(parse("")).to eq([])
  end

  it "parses a single move and line" do
    expect(parse("M 0 0 L 10 20")).to eq([cmd("M", 0.0, 0.0), cmd("L", 10.0, 20.0)])
  end

  it "treats subsequent M coordinate pairs as implicit L" do
    result = parse("M 1 2 3 4")
    expect(result).to eq([cmd("M", 1.0, 2.0), cmd("L", 3.0, 4.0)])
  end

  it "treats subsequent m coordinate pairs as implicit l" do
    result = parse("m 1 2 3 4")
    expect(result).to eq([cmd("m", 1.0, 2.0), cmd("l", 3.0, 4.0)])
  end

  it "parses H and V single-arg commands" do
    expect(parse("H 5 V 7")).to eq([cmd("H", 5.0), cmd("V", 7.0)])
  end

  it "parses cubic bezier C with 6 args" do
    result = parse("C 1 2 3 4 5 6")
    expect(result).to eq([cmd("C", 1.0, 2.0, 3.0, 4.0, 5.0, 6.0)])
  end

  it "parses repeated cubic beziers" do
    result = parse("C 1 2 3 4 5 6 7 8 9 10 11 12")
    expect(result.size).to eq(2)
    expect(result.last).to eq(cmd("C", 7.0, 8.0, 9.0, 10.0, 11.0, 12.0))
  end

  it "parses arc command with 7 args" do
    result = parse("A 25 25 -30 0 1 0.5 0.2")
    expect(result).to eq([cmd("A", 25.0, 25.0, -30.0, 0.0, 1.0, 0.5, 0.2)])
  end

  it "parses Z close with no args" do
    expect(parse("M 0 0 L 1 1 Z")).to eq([cmd("M", 0.0, 0.0), cmd("L", 1.0, 1.0), cmd("Z")])
  end

  it "handles no-separator between command letter and number" do
    expect(parse("M0,0L1,1")).to eq([cmd("M", 0.0, 0.0), cmd("L", 1.0, 1.0)])
  end

  it "handles scientific notation" do
    expect(parse("M 1e2 2E-1")).to eq([cmd("M", 100.0, 0.2)])
  end

  it "handles negative and decimal numbers" do
    expect(parse("M -1.5 0.25")).to eq([cmd("M", -1.5, 0.25)])
  end

  it "handles comma OR whitespace OR both as separators" do
    expected = [cmd("M", 1.0, 2.0), cmd("L", 3.0, 4.0)]
    expect(parse("M 1,2 L 3 4")).to eq(expected)
    expect(parse("M1,2L3,4")).to eq(expected)
    expect(parse("M 1 2 L 3 4")).to eq(expected)
  end

  it "preserves case (absolute vs relative)" do
    a = parse("M 0 0 L 1 1").first
    expect(a).to be_absolute
    r = parse("m 0 0 l 1 1").first
    expect(r).not_to be_absolute
  end

  it "raises FormatError when starting with a number" do
    expect { parse("1 2 3") }.to raise_error(Emfsvg::FormatError)
  end

  it "raises FormatError on incomplete command" do
    expect { parse("M 1") }.to raise_error(Emfsvg::FormatError)
  end

  it "parses a complex realistic path" do
    result = parse("M 10 10 L 100 10 L 100 100 L 10 100 Z")
    expect(result.size).to eq(5)
    expect(result.last.letter).to eq("Z")
  end
end

RSpec.describe Emfsvg::Svg::PathData::Command do
  it "is absolute when letter is uppercase" do
    expect(described_class.new(letter: "M", args: [])).to be_absolute
  end

  it "is relative when letter is lowercase" do
    expect(described_class.new(letter: "m", args: [])).not_to be_absolute
  end
end
