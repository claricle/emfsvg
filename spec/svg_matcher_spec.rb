# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::SvgMatcher do
  def cmp(a, b)
    described_class.compare(a, b)
  end

  it "reports equal for identical SVGs" do
    svg = '<svg><rect x="1" y="2"/></svg>'
    expect(cmp(svg, svg).equal).to be true
  end

  it "reports not equal for different element types" do
    a = "<svg><rect/></svg>"
    b = "<svg><ellipse/></svg>"
    expect(cmp(a, b).equal).to be false
  end

  it "treats numeric attributes as equal within tolerance" do
    a = %(<svg><rect x="100.0000" y="50.0000"/></svg>)
    b = %(<svg><rect x="100.3000" y="49.7000"/></svg>)
    expect(cmp(a, b).equal).to be true
  end

  it "rejects numeric differences beyond tolerance" do
    a = %(<svg><rect x="100.0000"/></svg>)
    b = %(<svg><rect x="200.0000"/></svg>)
    expect(cmp(a, b).equal).to be false
  end

  it "canonicalises auto-generated IDs (clip-N)" do
    a = %(<svg><rect clip-path="url(#clip-16807)"/></svg>)
    b = %(<svg><rect clip-path="url(#clip-282475249)"/></svg>)
    expect(cmp(a, b).equal).to be true
  end

  it "canonicalises pattern IDs (img-N-ref)" do
    a = %(<svg><rect fill="url(#img-1-ref)"/></svg>)
    b = %(<svg><rect fill="url(#img-5-ref)"/></svg>)
    expect(cmp(a, b).equal).to be true
  end

  it "compares path d-strings with numeric tolerance" do
    a = %(<svg><path d="M 0,0 L 100.0000,100.0000"/></svg>)
    b = %(<svg><path d="M 0,0 L 100.3000,100.2000"/></svg>)
    expect(cmp(a, b).equal).to be true
  end

  it "rejects path d-strings with different command letters" do
    a = %(<svg><path d="M 0,0 L 100,100"/></svg>)
    b = %(<svg><path d="M 0,0 C 100,100"/></svg>)
    expect(cmp(a, b).equal).to be false
  end

  it "compares <defs> children order-independently" do
    a = %(<svg><defs><clipPath id="a"/><clipPath id="b"/></defs></svg>)
    b = %(<svg><defs><clipPath id="b"/><clipPath id="a"/></defs></svg>)
    expect(cmp(a, b).equal).to be true
  end

  it "ignores whitespace-only text node differences" do
    a = %(<svg>  </svg>)
    b = %(<svg></svg>)
    expect(cmp(a, b).equal).to be true
  end

  it "compares text content semantically" do
    a = %(<svg><text>Hello World</text></svg>)
    b = %(<svg><text>Hello   World</text></svg>)
    expect(cmp(a, b).equal).to be true
  end

  it "returns a reason on mismatch for diagnostics" do
    result = cmp('<svg><rect x="1"/></svg>', '<svg><rect x="999"/></svg>')
    expect(result.equal).to be false
    expect(result.reason).to include("@x")
  end
end
