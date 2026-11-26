# frozen_string_literal: true

# Shared helpers for the dual-engine specs (claricle/emf#91): the canonical
# drawing spec, and real ENV hygiene — no test doubles anywhere; the switch
# is driven through real environment values and the real (or absent) native
# library.
module RuntimeEnvHelpers
  RUNTIME_ENV_KEYS = %w[EMFSVG_RUNTIME EMFSVG_NATIVE_LIB].freeze

  # Saves the switch env, forgets the memoized probes, runs, restores.
  # The env-named library path is remembered for the example (`saved_native_library`):
  # after the env is cleared, only the search dirs can answer, so an
  # explicitly pointed loader must still be reachable.
  def with_fresh_runtime
    saved = RUNTIME_ENV_KEYS.to_h { |key| [key, ENV.fetch(key, nil)] }
    @saved_native_library = saved.fetch("EMFSVG_NATIVE_LIB", nil)
    RUNTIME_ENV_KEYS.each { |key| ENV.delete(key) }
    Emfsvg::Runtime.reset!
    yield
  ensure
    saved.each do |key, value|
      ENV[key] = value
    end
    @saved_native_library = nil
    Emfsvg::Runtime.reset!
  end

  # The library path the env named before the hygiene run, or nil.
  def saved_native_library
    @saved_native_library
  end

  # Points the loader at a deterministic path that cannot exist: the
  # library is missing. (No temp-dir churn; the path is never created.)
  def with_missing_native_library
    ENV["EMFSVG_NATIVE_LIB"] = File.join("", "nonexistent-emfsvg-spec", "libeikogram_ffi.dylib")
    Emfsvg::Runtime.reset!
  end

  def with_native_library(path)
    ENV["EMFSVG_NATIVE_LIB"] = path
    Emfsvg::Runtime.reset!
  end

  def with_runtime_mode(value)
    ENV["EMFSVG_RUNTIME"] = value
  end

  # The recorded parity contract for the render lanes (the emf88 gate):
  # byte equality, with the canonical quirk normalization as the recorded
  # equivalence — the SVG model declares the renderer's tag-grammar
  # whitespace non-representable, so both sides are compared under the same
  # normalization (quoted values never touched).
  def same_render_output?(expected, actual)
    expected == actual ||
      Emfsvg::SpecSupport::QuirkNormalization.normalize(expected) ==
        Emfsvg::SpecSupport::QuirkNormalization.normalize(actual)
  end
end

RSpec.configure do |config|
  config.include RuntimeEnvHelpers
end
