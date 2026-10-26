# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    module CalibrationProductionPreflightFixture
      def build_adapter_for_outcome(directory, outcome)
        FileUtils.mkdir_p(directory)
        File.write(File.join(directory, "emf.rb"), "runtime")
        library_path = File.join(directory, "native.dylib")
        File.write(library_path, "native")
        input = production_input(directory, "input.emf", "fixture", outcome)
        production_adapter(directory, [input], library: library_path)
      end
    end
  end
end
