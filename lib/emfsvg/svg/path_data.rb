# frozen_string_literal: true

require "strscan"

module Emfsvg
  module Svg
    # Namespace for the SVG path-data parser. Pure parser, no EMF
    # concerns. The translation layer (Phase 03 path handler) consumes
    # the resulting Command list.
    module PathData
      autoload :Command, "emfsvg/svg/path_data/command"

      # Arg count per command letter. M repeats as L (handled in parser).
      ARG_COUNTS = {
        "M" => 2, "L" => 2, "H" => 1, "V" => 1, "C" => 6, "S" => 4,
        "Q" => 4, "T" => 2, "A" => 7, "Z" => 0
      }.freeze

      # ARG_COUNTS keyed by the letter as written, so the parser does not
      # upcase a fresh String per token to look it up.
      LETTER_ARG_COUNTS = ARG_COUNTS.each_with_object({}) do |(letter, count), counts|
        counts[letter] = count
        counts[letter.downcase] = count
      end.freeze

      # Frozen command-letter Strings keyed by the Symbol the Scanner
      # emits, shared by every Command rather than allocated per token.
      LETTERS = LETTER_ARG_COUNTS.keys.to_h { |letter| [letter.to_sym, letter.freeze] }.freeze

      # Shared by every zero-argument command (Z/z).
      NO_ARGS = [].freeze

      # Stateful parser walks the string once, emitting Commands as
      # enough args accumulate for the current letter. Implicit repeats:
      # subsequent arg groups after M/m are treated as L/l.
      module Parser
        module_function

        def parse(string)
          return [] if string.nil? || string.empty?

          commands = []
          scanner = Scanner.new(string)
          current_letter = nil
          args = nil

          while (token = scanner.next_token)
            case token
            when Symbol # command letter
              flush_command(commands, current_letter, args) if current_letter && args.any?
              current_letter = LETTERS.fetch(token) { token.to_s }
              args = []
              # Zero-arg commands (Z/z) emit immediately.
              if LETTER_ARG_COUNTS.fetch(current_letter, 1).zero?
                emit_command(commands, current_letter, NO_ARGS)
                current_letter = nil
              end
            when Numeric
              raise FormatError, "path data begins with a number: #{string.inspect}" if current_letter.nil?

              args << token
              if args.size == (LETTER_ARG_COUNTS[current_letter] || ARG_COUNTS.fetch(current_letter.upcase))
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
          raise FormatError, "unknown path command: #{letter}" unless LETTER_ARG_COUNTS.key?(letter)

          commands << Command.new(letter: letter, args: args)
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
        SEPARATORS_RE = /[ \t\n\r,]+/

        # The Symbol for each command-letter byte, so a letter is read
        # without allocating a String for it.
        LETTER_SYMBOLS = (("A".."Z").to_a + ("a".."z").to_a).to_h { |letter| [letter.ord, letter.to_sym] }.freeze
        private_constant :LETTER_SYMBOLS

        def initialize(string)
          @string = string
          @scanner = StringScanner.new(string)
        end

        def next_token
          @scanner.skip(SEPARATORS_RE)
          return nil if @scanner.eos?

          letter = LETTER_SYMBOLS[@string.getbyte(@scanner.pos)]
          return read_number unless letter

          @scanner.pos += 1
          letter
        end

        private

        # A number is normally right at the cursor. Anything else is
        # skipped up to the next number, as the scan has always done.
        def read_number
          number = @scanner.scan(NUMBER_RE)
          return number.to_f if number

          position = @scanner.charpos
          unless @scanner.skip_until(NUMBER_RE)
            raise FormatError, "expected number at position #{position} in path data"
          end

          @scanner.matched.to_f
        end
      end
    end
  end
end
