# frozen_string_literal: true

require "spec_helper"

# The path-data tokenizer was rewritten on StringScanner. This pins it to
# the character-by-character implementation it replaced, token for token and
# error for error, over valid, malformed and junk-laden input.
# Verbatim copy of the previous implementation.
module PreviousPathData
  ARG_COUNTS = Emfsvg::Svg::PathData::ARG_COUNTS
  Command = Emfsvg::Svg::PathData::Command
  FormatError = Emfsvg::FormatError

  module Parser
    module_function

    def parse(string)
      return [] if string.nil? || string.empty?

      commands = []
      scanner = Scanner.new(string)
      current_letter = nil
      args = []

      while (token = scanner.next_token)
        case token
        when Symbol # command letter
          flush_command(commands, current_letter, args) if current_letter && args.any?
          current_letter = token.to_s
          args = []
          # Zero-arg commands (Z/z) emit immediately.
          if ARG_COUNTS.fetch(current_letter.upcase, 1).zero?
            emit_command(commands, current_letter, [])
            current_letter = nil
          end
        when Numeric
          raise FormatError, "path data begins with a number: #{string.inspect}" if current_letter.nil?

          args << token
          if args.size == ARG_COUNTS.fetch(current_letter.upcase)
            emit_command(commands, current_letter, args)
            args = []
            current_letter = implicit_repeat_letter(current_letter)
          end
        end
      end

      flush_command(commands, current_letter, args) if current_letter && args.any?
      commands
    end

    def emit_command(commands, letter, args)
      raise FormatError, "unknown path command: #{letter}" unless ARG_COUNTS.key?(letter.upcase)

      commands << Command.new(letter: letter, args: args.dup)
    end

    def flush_command(_commands, letter, args)
      return unless letter
      return if args.empty?

      expected = ARG_COUNTS.fetch(letter.upcase, 0)
      return if args.size == expected

      raise FormatError, "path command #{letter} expected #{expected} args, got #{args.size}"
    end

    # M/m repeats as L/l per SVG spec; all other commands repeat as
    # themselves.
    def implicit_repeat_letter(letter)
      case letter
      when "M" then "L"
      when "m" then "l"
      else letter
      end
    end
  end

  # Character-stream tokenizer for path data. Emits command letters
  # as Symbols (e.g. :M, :z) and numbers as Floats.
  class Scanner
    NUMBER_RE = /[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?/

    def initialize(string)
      @string = string
      @pos = 0
    end

    def next_token
      skip_separators
      return nil if @pos >= @string.length

      char = @string[@pos]
      if command_letter?(char)
        @pos += 1
        char.to_sym
      else
        read_number
      end
    end

    private

    def skip_separators
      @pos += 1 while @pos < @string.length && separator?(@string[@pos])
    end

    def separator?(char)
      case char
      when " ", "\t", "\n", "\r", "," then true
      else false
      end
    end

    def command_letter?(char)
      ("A".."Z").cover?(char) || ("a".."z").cover?(char)
    end

    def read_number
      match = @string.match(NUMBER_RE, @pos)
      raise FormatError, "expected number at position #{@pos} in path data" unless match

      @pos = match.end(0)
      match.to_s.to_f
    end
  end
end

RSpec.describe Emfsvg::Svg::PathData do
  def outcome
    [:ok, yield]
  rescue StandardError => e
    [:error, e.class.name.sub("PreviousPathData::", ""), e.message]
  end

  def tokens(scanner_class, string)
    scanner = scanner_class.new(string)
    out = []
    loop do
      token = scanner.next_token
      break if token.nil?

      out << token
    end
    out
  end

  def generated_inputs
    random = Random.new(20_261_022)
    alphabet = ["M", "m", "L", "l", "H", "V", "C", "c", "S", "Q", "T", "A", "Z", "z", "x", "e", "E",
                " ", ",", "\n", "\t", "\r", "-", "+", ".", "0", "1", "2", "9", "5", "%", "#", "(", "\u00e9"]
    fixed = ["M 1 2 L 3 4 Z", "M1,2L3-4", "M.5.5L1e2,-1E-2", "M 1 2 3 4 5", "L 1 2", "M 1 2 ?? L 5 6",
             "M 1 2 -", "M 1 2 %", "1 2", "Mx", "M 1e", "M 1e+", "M 1.2.3", "M-1-2", "Z Z", "M 1 2 #", ""]
    fixed + Array.new(4000) { Array.new(random.rand(1..24)) { alphabet[random.rand(alphabet.size)] }.join }
  end

  it "tokenizes exactly as the previous scanner did" do
    generated_inputs.each do |input|
      previous = outcome { tokens(PreviousPathData::Scanner, input) }
      current = outcome { tokens(described_class::Scanner, input) }
      expect(current).to eq(previous), "tokens differ for #{input.inspect}"
    end
  end

  it "parses exactly as the previous parser did" do
    generated_inputs.each do |input|
      previous = outcome { PreviousPathData::Parser.parse(input) }
      current = outcome { described_class::Parser.parse(input) }
      expect(current).to eq(previous), "parse differs for #{input.inspect}"
    end
  end
end
