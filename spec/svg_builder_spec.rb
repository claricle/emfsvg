# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::SvgBuilder do
  it "emits an XML declaration" do
    out = described_class.new.declaration.to_s
    expect(out).to start_with(%(<?xml version="1.0"))
  end

  it "emits a single tag" do
    out = described_class.new.tag("rect", { "x" => 0, "y" => 0 }, single: true).to_s
    expect(out).to include('<rect x="0" y="0" />')
  end

  it "emits a paired tag with content" do
    builder = described_class.new
    out = builder.tag("g") { builder.tag("rect", single: true) }.to_s
    expect(out).to include("<g>\n  <rect />\n</g>\n")
  end

  it "escapes XML special characters in attributes" do
    out = described_class.new.tag("text", { "data" => %(a<b"c>&d) }, single: true).to_s
    expect(out).to include('data="a&lt;b&quot;c&gt;&amp;d"')
  end

  it "escapes XML special characters in text content" do
    out = described_class.new.text(%(a<b>c&d)).to_s
    expect(out).to include("a&lt;b&gt;c&amp;d")
  end

  it "indents nested content" do
    builder = described_class.new
    out = builder.tag("a") { builder.tag("b") { builder.tag("c", single: true) } }.to_s
    expect(out).to include("<a>\n  <b>\n    <c />\n  </b>\n</a>\n")
  end
end
