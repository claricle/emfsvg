# frozen_string_literal: true

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
  end
end
