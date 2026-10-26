# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Embedded PNG payload preservation" do
  let(:png_base64) do
    "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAIAAAACUFjqAAAAUElEQVQYlW2OwQ3AMAgDrxJjwP6DAXO0j1QJQfiFMGfzvBBKKG7DIAGgjIrf" \
      "ni4SQPwsrHJLmy4ZZdVsyKulhm/utBT6ytHbzv74uhDvXJV9Tw0bLHsWOIMAAAAAAElFTkSuQmCC"
  end
  let(:svg) do
    <<~SVG
      <svg width="100" height="100">
      <image x="12" y="13" width="30" height="40" href="data:image/png;base64,#{png_base64}"/>
      <rect x="50" y="60" width="3" height="4" fill="#123456"/>
      </svg>
    SVG
  end
  let(:bytes) { Emfsvg.from_svg(svg) }
  let(:output) { Emfsvg.from_bytes(bytes) }

  it "preserves the compressed RGB payload and its destination across conversions" do
    expect(output).to include("data:image/png;base64,#{png_base64}")
    expect(output).to include('width="30.0000" height="40.0000" x="12.0000" y="13.0000"')
    expect(output).to include('<rect x="50" y="60" width="3" height="4" fill="#123456"/>')
    expect(Emfsvg.from_bytes(Emfsvg.from_svg(output))).to eq(output)
  end

  context "with malformed PNG bytes" do
    let(:png_base64) { Base64.strict_encode64("not a PNG") }

    it "skips the image and preserves the following shape" do
      expect(output).not_to include("<image ")
      expect(output).to include('<rect x="50" y="60" width="3" height="4" fill="#123456"/>')
    end
  end
end
