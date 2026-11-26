# frozen_string_literal: true

module Emfsvg
  # Picks the engine behind {Emfsvg::Runtime}'s dual-engine entry points:
  # the Rust EMF -> VIM -> SVG conversion shipped in the vectory-rs
  # workspace (loaded through {Emfsvg::Native}), or the gem's own Ruby lane.
  #
  # `EMFSVG_RUNTIME` selects the mode:
  #
  # - `auto` (default) — native when the eikogram-ffi library loads, Ruby
  #   otherwise. A missing engine is the designed fallback, never an error;
  #   a PRESENT engine is always used, so a native failure surfaces as the
  #   native error's named Ruby class — never a silent switch.
  # - `ruby` — never touch the native engine; the Ruby lane answers even
  #   when the library is loadable.
  # - `native` — require it: a missing library raises
  #   {Runtime::EngineUnavailableError}, the named error. CI's native lane
  #   proves the Rust path.
  #
  # The class-level API (`Emfsvg.from_bytes` and friends) remains the Ruby
  # lane untouched; {Runtime} is the dispatch the ledger and dual-engine
  # callers drive — the vectory#110 shape, applied to this gem.
  module Runtime
    ENV_KEY = "EMFSVG_RUNTIME"
    MODES = %w[auto ruby native].freeze

    # The native engine is demanded (or the operation has no Ruby lane) and
    # it is not loadable. Named, never a silent switch.
    class EngineUnavailableError < ::Emfsvg::Error; end

    # The renderer's option keys, for naming what the v1 native ABI cannot
    # carry.
    OPTION_KEYS = %i[namespace width height verbose emf_plus].freeze

    class << self
      # @return [String] the validated mode
      # @raise [ArgumentError] when EMFSVG_RUNTIME names no mode
      def mode
        value = ENV.fetch(ENV_KEY, nil)
        return "auto" if value.nil? || value.empty?
        return value if MODES.include?(value)

        raise ArgumentError,
              "#{ENV_KEY} must be one of #{MODES.join(', ')}, " \
              "got #{value.inspect}"
      end

      # Whether the native engine is loadable in this process.
      def native?
        !library.nil?
      end

      # The engine this process dispatches to: :native or :ruby.
      def engine
        selected = mode
        return :ruby if selected == "ruby"
        return :native if selected == "native"

        library.nil? ? :ruby : :native
      end

      # Parse + render EMF bytes through the selected engine.
      #
      # The v1 native ABI renders default options (the renderer's
      # width/height/namespace overrides ride a future suffixed entry
      # point, snapshot-v4's evolution rule); non-default options under the
      # native engine raise ArgumentError — a divergence is named, never
      # silent.
      #
      # @return [String] the SVG bytes
      # @raise [Runtime::EngineUnavailableError] when the engine is demanded
      #   and not loadable
      def from_bytes(content, **options)
        requested = Options.new(**options)
        return Emfsvg.from_bytes(content, **options) if engine == :ruby

        defaulted = requested == Options.new
        unless defaulted
          raise ArgumentError,
                "the native v1 render ABI carries no options " \
                "(snapshot-v4's evolution rule); non-default " \
                "#{offending_options(requested).inspect} under the native " \
                "engine would diverge silently"
        end

        native_dispatch { |library| library.render_emf(content) }
      end

      # Execute the drawing described by the canonical step spec
      # ({Emfsvg::RuntimeSteps} — the shape both lanes interpret).
      #
      # @param steps [Array<Hash>] the canonical step spec
      # @return [String] the rendered bytes
      def drawing(content, steps:)
        return RuntimeSteps.pipeline(steps).call(content) if engine == :ruby

        RuntimeSteps.validate_native(steps)
        native_dispatch { |library| library.render_emf(content) }
      end

      # The Native library, or nil. Probed once: an absent library means
      # "use Ruby" in `auto` mode.
      def library
        Native.library
      end

      # Forget the memoized probes (specs only).
      def reset!
        Native.reset!
      end

      private

      def offending_options(requested)
        defaults = Options.new
        OPTION_KEYS.each_with_object({}) do |key, offenders|
          value = requested.public_send(key)
          offenders[key] = value unless defaults.public_send(key) == value
        end
      end

      def native_dispatch
        lib = library
        return yield(lib) unless lib.nil?

        raise EngineUnavailableError,
              "#{ENV_KEY} demands the native engine and it is not loadable " \
              "(#{Native::LIBRARY_ENV} not set and no #{native_name} in " \
              "lib/emfsvg/native/ or under the vectory-rs workspace target/)"
      end

      def native_name
        case RbConfig::CONFIG["host_os"]
        when /darwin/ then "libeikogram_ffi.dylib"
        when /mswin|mingw/ then "eikogram_ffi.dll"
        else "libeikogram_ffi.so"
        end
      end
    end
  end
end
