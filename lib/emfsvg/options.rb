# frozen_string_literal: true

module Emfsvg
  # Render options. Frozen on construction; carry through the renderer.
  Options = Struct.new(:namespace, :width, :height, :verbose, :emf_plus, keyword_init: true) do
    def initialize(namespace: nil, width: nil, height: nil, verbose: false, emf_plus: false)
      super
      freeze
    end
  end
end
