# frozen_string_literal: true

require "spec_helper"

# Color.parse was rewritten to allocate less. This pins it to the
# implementation it replaced over every named colour, every hex and
# rgb() form, and a seeded set of malformed strings.
RSpec.describe Emfsvg::Svg::Color do
  # Verbatim body of the previous Color.parse.
  def previous_parse(value)
    return described_class::NULL if value.nil? || value.strip == "none" || value.strip.empty?

    v = value.strip
    if (m = v.match(/\A#([0-9a-fA-F]{3})\z/))
      described_class.expand_short_hex(m[1])
    elsif (m = v.match(/\A#([0-9a-fA-F]{6})\z/))
      described_class.new(red: m[1][0, 2].to_i(16), green: m[1][2, 2].to_i(16), blue: m[1][4, 2].to_i(16))
    elsif (m = v.match(/\Argb\(\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(-?\d+)\s*\)\z/i))
      described_class.new(red: m[1].to_i, green: m[2].to_i, blue: m[3].to_i)
    elsif described_class::NAMED_COLORS.key?(v.downcase)
      r, g, b = described_class::NAMED_COLORS[v.downcase]
      described_class.new(red: r, green: g, blue: b)
    else
      raise Emfsvg::FormatError, "unsupported SVG color: #{value.inspect}"
    end
  end

  def outcome(&)
    [:ok, yield.then { |c| [c.null?, c.red, c.green, c.blue] }]
  rescue StandardError => e
    [:error, e.class, e.message]
  end

  def inputs
    random = Random.new(20_261_022)
    alphabet = %w[# r g b ( ) , - + 0 1 5 9 a f F A G x] + [" ", "\t", "\n", "é"]
    named = described_class::NAMED_COLORS.keys.flat_map { |n| [n, n.upcase, " #{n.capitalize} "] }
    hex3 = (0..4095).map { |n| format("#%03x", n) }
    hex6 = Array.new(3000) { format("#%06X", random.rand(0x1000000)) }
    rgb = ["rgb(1,2,3)", "RGB( 255 , -5 , 300 )", "rgb(1,2)", "rgb(1,2,3,4)", "rgb(1.5,2,3)"]
    random_strings = Array.new(4000) { Array.new(random.rand(1..10)) { alphabet[random.rand(alphabet.size)] }.join }
    [nil, "", " ", "none", " none ", "None", "#", "#12", "#1234", "#12345", "#1234567", "#ggg",
     "currentColor", "transparent"] + named + hex3 + hex6 + rgb + random_strings
  end

  it "parses exactly as the previous implementation did" do
    inputs.each do |input|
      expect(outcome { described_class.parse(input) }).to eq(outcome { previous_parse(input) }),
                                                          "differs for #{input.inspect}"
    end
  end
end
