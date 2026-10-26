# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Embedded JPEG image roundtrip" do
  let(:jpeg_base64) do
    "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGB" \
      "YUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wgARCAAK" \
      "AAoDAREAAhEBAxEB/8QAFgABAQEAAAAAAAAAAAAAAAAABQYH/8QAFQEBAQAAAAAAAAAAAAAAAAAABQf/2gAMAwEAAhADEAAAAY4hpBODYRQ6qt" \
      "ZDP//EABwQAAEDBQAAAAAAAAAAAAAAAAMAAQUCBBITIf/aAAgBAQABBQKJvxaHnugJUsnX/8QAHxEAAgECBwAAAAAAAAAAAAAAAAECAwQFBhEV" \
      "ISIx/9oACAEDAQE/AczXm46xj6Twrs+CqNI//8QAHhEAAQQBBQAAAAAAAAAAAAAAAAECAyEFBhEUFmL/2gAIAQIBAT8BiwnNpEOleTT7UqhsbN" \
      "ko/8QAGhAAAgIDAAAAAAAAAAAAAAAAAAECMiIxkf/aAAgBAQAGPwJSk8ixZ9Ns/8QAGRAAAgMBAAAAAAAAAAAAAAAAAAERIVHx/9oACAEBAAE/" \
      "IUlKlLSBgrAu8f/aAAwDAQACAAMAAAAQ2Q//xAAaEQEBAAIDAAAAAAAAAAAAAAABABEhQcHw/9oACAEDAQE/ENyedyqPJmuVlKpf/8QAGhEBAA" \
      "IDAQAAAAAAAAAAAAAAAQAhMUGRwf/aAAgBAgEBPxCrfg0PMW1ciKuDRP/EABkQAQEBAAMAAAAAAAAAAAAAAAEAESExQf/aAAgBAQABPxAxsaVp" \
      "hAAoA9RBCDgBQ4Ki+6v/2Q=="
  end
  let(:mime) { "image/jpeg" }
  let(:href) { "data:#{mime};base64,#{jpeg_base64}" }
  let(:svg) do
    <<~SVG
      <svg width="100" height="100">
      <image x="12" y="13" width="30" height="40" href="#{href}"/>
      <rect x="50" y="60" width="3" height="4" fill="#123456"/>
      </svg>
    SVG
  end
  let(:bytes) { Emfsvg.from_svg(svg) }
  let(:output) { Emfsvg.from_bytes(bytes) }
  let(:rendered_jpeg) { Base64.strict_decode64(output[%r{data:image/jpg;base64,([^"]+)}, 1]) }
  let(:jpeg_bytes) { Base64.strict_decode64(jpeg_base64) }

  it "preserves the JPEG payload and destination alongside the following shape" do
    expect(output.lines.grep(/<image /).size).to eq(1)
    image = Emf.parse(bytes).records.map(&:wire).grep(Emf::Emr::Binary::Records::StretchDIBits).first
    expect([image.cx_src.to_i, image.cy_src.to_i]).to eq([10, 10])
    expect(rendered_jpeg).to eq(jpeg_bytes + ("\0" * ((3 - (jpeg_bytes.bytesize % 3)) % 3)))
    expect(output).to include('width="30.0000" height="40.0000" x="12.0000" y="13.0000"', 'style="fill:#123456"')
    expect(Emfsvg.from_bytes(Emfsvg.from_svg(output))).to eq(output)
  end

  context "with the renderer's image/jpg spelling" do
    let(:mime) { "image/jpg" }

    it "retains the image on subsequent roundtrips" do
      expect(output.lines.grep(/<image /).size).to eq(1)
      expect(rendered_jpeg).to start_with(jpeg_bytes)
    end
  end

  context "with a truncated JPEG frame" do
    let(:jpeg_base64) { Base64.strict_encode64("\xFF\xD8\xFF\xC0\x00\x11".b) }

    it "skips the malformed image and preserves the following shape" do
      expect(output).not_to include("<image ")
      expect(output).to include('style="fill:#123456"')
    end
  end
end
