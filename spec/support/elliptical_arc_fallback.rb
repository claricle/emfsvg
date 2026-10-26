# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    module EllipticalArcFallback
      module_function

      def flatten(data)
        commands = Emfsvg::Svg::PathData::Parser.parse(data)
        Emfsvg::Translation::Handlers::PathFlattener.flatten(commands).first
      end
    end
  end
end
