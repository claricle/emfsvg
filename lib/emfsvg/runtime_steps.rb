# frozen_string_literal: true

module Emfsvg
  # The canonical drawing spec's Ruby interpretation — the same shape the
  # native engine reads over the FFI (vectory-rs/crates/eikogram-ffi). One
  # interchange shape, two lanes:
  #
  #     {"name" => "render", "options" => {}}
  #
  # The spec has one step for now: THE drawing — EMF bytes through the
  # renderer's default options (the v1 native ABI renders default options;
  # snapshot-v4's evolution rule adds option transport as a new suffixed
  # entry point, and this spec grows with it). String keys, JSON-shaped:
  # it crosses the FFI as the pipeline spec verbatim and drives this gem's
  # Ruby lane locally.
  module RuntimeSteps
    STEPS = {
      "render" => lambda do |spec|
        options = spec.fetch("options", {})
        options = options.transform_keys(&:to_sym)
        ->(content) { Emfsvg.from_bytes(content, **options) }
      end
    }.freeze

    private_constant :STEPS

    class << self
      # Builds one step from a canonical spec entry.
      #
      # @return [Proc] the step's Ruby-lane callable over EMF bytes
      # @raise [ArgumentError] on an unknown step name
      def build(spec)
        name = spec.fetch("name")
        STEPS.fetch(name) { raise ArgumentError, "unknown step name '#{name}'" }
             .call(spec)
      end

      # Builds the pipeline: the steps composed over one drawing's bytes.
      def pipeline(steps)
        built = steps.map { |spec| build(spec) }
        ->(content) { built.reduce(content) { |bytes, step| step.call(bytes) } }
      end

      # The native side answers exactly the one drawing its v1 ABI
      # implements; anything else would diverge silently, so it is named
      # before the call.
      #
      # @raise [ArgumentError] when the spec is not the single render step
      #   with default options
      def validate_native(steps)
        return if steps == [{ "name" => "render" }]

        raise ArgumentError,
              "the native v1 render ABI implements only " \
              '[{"name" => "render"}] with default options; got ' \
              "#{steps.inspect}"
      end
    end
  end
end
