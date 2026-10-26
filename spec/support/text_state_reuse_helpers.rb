# frozen_string_literal: true

module Emfsvg
  module SpecSupport
    module TextStateReuseHelpers
      def translate(children)
        Emfsvg.from_svg(%(<svg width="100" height="100">#{children}</svg>))
      end

      def text(attributes = "", content = "<![CDATA[]]>")
        %(<text x="2" y="20" font-family="Arial" font-size="0" #{attributes}>#{content}</text>)
      end

      def records(bytes)
        parsed = Emf.parse(bytes)
        expect(parsed.errors).to be_empty
        parsed.records
      end

      def font_count(bytes)
        records(bytes).count { |record| record.wire.i_type == 82 }
      end
    end
  end
end
