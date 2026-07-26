# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::SvgBuilder do
  it "appends a single tag with attributes and no leading space before />" do
    out = described_class.new.tag("rect", { "x" => 0, "y" => 0 }, single: true).to_s
    expect(out).to include('<rect x="0" y="0"/>')
  end

  it "appends a paired tag with content" do
    builder = described_class.new
    out = builder.tag("g") { builder.tag("rect", single: true) }.to_s
    expect(out).to include("<g><rect/></g>")
  end

  it "escapes XML special characters in attributes" do
    out = described_class.new.tag("text", { "data" => %(a<b"c>&d) }, single: true).to_s
    expect(out).to include('data="a&lt;b&quot;c&gt;&amp;d"')
  end

  it "escapes XML special characters in text content" do
    out = described_class.new.text(%(a<b>c&d)).to_s
    expect(out).to include("a&lt;b&gt;c&amp;d")
  end

  it "rawln appends with trailing newline" do
    out = described_class.new.rawln("<g>").to_s
    expect(out).to eq("<g>\n")
  end

  it "raw appends without trailing newline" do
    out = described_class.new.raw("<g>").to_s
    expect(out).to eq("<g>")
  end
end
