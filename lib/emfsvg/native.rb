# frozen_string_literal: true

require "fiddle"
require "fiddle/struct"
require "json"
require "rbconfig"

module Emfsvg
  # Loads the eikogram-ffi cdylib (the EMF -> VIM -> SVG conversion's native
  # render engine, claricle/emf#91) and calls its entry points.
  #
  # The shared library is looked up in this order:
  #   1. ENV["EMFSVG_NATIVE_LIB"] — exact file path; when set, nothing else
  #      is searched.
  #   2. lib/emfsvg/native/ inside an installed platform gem (precompiled,
  #      no compile at install).
  #   3. ../vectory/vectory-rs/target/release, then .../debug — the org's
  #      co-checkout convention (the conversion lives in the vectory-rs
  #      workspace; claricle repos sit side by side).
  #
  # A missing library is NOT an error: {Emfsvg::Runtime} falls back to the
  # Ruby lane in `auto` mode. A library that exists but fails to load raises
  # {Native::NativeError} — a present-but-broken engine never silently
  # switches (the etassia#491 law).
  #
  # Binding decision (vectory-rs/crates/eikogram-ffi/README.md): Fiddle +
  # cdylib with caller-allocated output buffers — zero runtime gem
  # dependencies, the svgpng-precedent convention, one binding style with
  # the parse lane (Emf::Native) and the vectory engine (Vectory::Native).
  module Native
    LIBRARY_ENV = "EMFSVG_NATIVE_LIB"
    REPO_ROOT = File.expand_path("../..", __dir__)
    PACKAGED_DIR = File.join(__dir__, "native").freeze
    SEARCH_DIRS = [
      PACKAGED_DIR,
      File.join(REPO_ROOT, "..", "vectory", "vectory-rs", "target", "release"),
      File.join(REPO_ROOT, "..", "vectory", "vectory-rs", "target", "debug")
    ].freeze

    # The engine is demanded but nothing loadable exists. Named, never a
    # silent switch.
    class Unavailable < LoadError; end

    # The library exists but its ABI failed to load, or a call failed at the
    # ABI boundary (bad status, bad JSON body).
    class NativeError < ::Emfsvg::Error; end

    # Opens one cdylib and owns its entry points.
    class Library
      # Mirrors `struct EikogramBuf` in vectory-rs/crates/eikogram-ffi
      # (caller-allocated: pointer + length).
      BUF = Fiddle::CStructBuilder.create(Fiddle::CStruct,
                                          [Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T],
                                          %w[ptr len]).freeze

      STATUS_OK = 0
      STATUS_INVALID_ARGUMENT = 1
      STATUS_PARSING = 2
      STATUS_RENDER = 3
      STATUS_SERIALIZE = 4

      # The JSON body's "class" names map to these Ruby constructors. A
      # class maps to `klass, message`; a lambda receives the parsed body
      # (the resource-limit error carries its keyword fields, snapshot-v4).
      ERROR_CLASSES = {
        "ParseError" => ::Emfsvg::ParseError,
        "RenderError" => ::Emfsvg::RenderError,
        "ResourceLimitError" => lambda do |info|
          limit = info.fetch("limit", 0)
          ::Emfsvg::ResourceLimitError.new(
            resource: info.fetch("resource", "record_count").to_sym,
            limit: limit,
            actual: info.fetch("actual") { limit }
          )
        end
      }.freeze

      attr_reader :path

      def initialize(path)
        @path = path
        @handle = Fiddle::Handle.new(path, Fiddle::RTLD_NOW)
        @abi_version = Fiddle::Function.new(@handle["eikogram_v1_abi_version"],
                                            [], Fiddle::TYPE_INT)
        @render = Fiddle::Function.new(@handle["eikogram_v1_render_emf"],
                                       [Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T,
                                        Fiddle::TYPE_VOIDP],
                                       Fiddle::TYPE_INT)
        @free = Fiddle::Function.new(@handle["eikogram_v1_free"],
                                     [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
        check_abi_version
      rescue Fiddle::DLError => e
        raise NativeError, "Cannot load the emfsvg native engine at #{path}: #{e.message}"
      end

      # The ABI version the library was built with.
      def abi_version
        @abi_version.call
      end

      # EMF metafile bytes -> the emfsvg renderer's SVG bytes.
      def render_emf(content)
        buffers([content]) do |pointers, out|
          copy(out, @render.call(pointers[0], pointers[0].size, out.to_ptr))
        end
      end

      private

      def check_abi_version
        version = abi_version
        return if version == 1

        raise NativeError,
              "emfsvg native engine ABI version mismatch at #{@path} " \
              "(expected 1, got #{version})"
      end

      # One call owns its buffers until the output copy completes: the input
      # pointers and the output descriptor are released on every exit path,
      # with the native buffer freed first (the svgpng discipline).
      def buffers(contents)
        session = CallBuffers.new(contents)
        yield session.input_pointers, session.output
      ensure
        session&.release(@free)
      end

      # The allocations and their release order for one ABI call.
      class CallBuffers
        attr_reader :input_pointers, :output

        def initialize(contents)
          @owned = []
          @input_pointers = contents.map { |content| own_bytes(content) }
          @output = BUF.malloc(Fiddle::RUBY_FREE)
          @output.to_ptr[0, BUF.size] = "\0".b * BUF.size
        end

        # Native buffer first, then the Ruby-owned allocations.
        def release(free_function)
          free_function&.call(output.to_ptr)
          output.to_ptr.call_free
          @owned.each(&:call_free)
        end

        private

        def own_bytes(content)
          bytes = content.to_s.b
          pointer = Fiddle::Pointer.malloc([bytes.bytesize, 1].max, Fiddle::RUBY_FREE)
          pointer[0, bytes.bytesize] = bytes
          @owned << pointer
          pointer
        end
      end

      # Copies the result out, then maps a nonzero status (a JSON error body
      # naming the Ruby class) to the named error. Never falls back here:
      # error mapping is the caller's ({Emfsvg::Runtime}) decision.
      def copy(out, status)
        body = out.ptr.null? ? "".b : out.ptr[0, out.len].b
        return body if status == STATUS_OK

        raise_native_status(status, body)
      end

      def raise_native_status(status, body)
        info = parse_error_body(status, body)
        if info.is_a?(Hash)
          mapped = ERROR_CLASSES.fetch(info["class"], NativeError)
          raise mapped.is_a?(Proc) ? mapped.call(info) : mapped, info["message"].to_s
        end

        raise NativeError, "emfsvg native engine returned status #{status}: #{body}"
      end

      def parse_error_body(status, body)
        return nil unless [STATUS_INVALID_ARGUMENT, STATUS_PARSING,
                           STATUS_RENDER, STATUS_SERIALIZE].include?(status)

        JSON.parse(body)
      rescue JSON::ParserError
        nil
      end
    end

    class << self
      # Path of the library that would be loaded, or nil.
      def library_path
        override = ENV.fetch(LIBRARY_ENV, nil)
        return (File.file?(override) ? override : nil) if override && !override.empty?

        SEARCH_DIRS.map { |dir| File.join(dir, library_filename) }.find { |path| File.file?(path) }
      end

      # Whether a loadable library exists in this process. A file that fails
      # to load raises; only a genuinely missing library answers false.
      def available?
        return false if library_path.nil?

        !library.nil?
      end

      # The memoized Library, or nil when no library file exists. Probed
      # once; the answer is process-lifetime (specs use reset!).
      def library
        return @library if instance_variable_defined?(:@library)

        path = library_path
        @library = path.nil? ? nil : Library.new(path)
      rescue Fiddle::DLError => e
        raise NativeError, "emfsvg native engine failed to load: #{e.message}"
      end

      # Forget the memoized probe (specs only).
      def reset!
        return unless instance_variable_defined?(:@library)

        remove_instance_variable(:@library)
      end

      private

      def library_filename
        case RbConfig::CONFIG["host_os"]
        when /darwin/ then "libeikogram_ffi.dylib"
        when /mswin|mingw/ then "eikogram_ffi.dll"
        else "libeikogram_ffi.so"
        end
      end
    end
  end
end
