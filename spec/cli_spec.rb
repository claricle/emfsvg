# frozen_string_literal: true

require "spec_helper"
require "open3"
require "tmpdir"

RSpec.describe "exe/emfsvg CLI" do
  let(:exe) { File.expand_path("../exe/emfsvg", __dir__) }
  let(:fixture) { Emfsvg::SpecSupport::FixturePath.fixture("image1.emf") }

  def run(*args)
    env = { "BUNDLE_GEMFILE" => File.expand_path("../Gemfile", __dir__), "PATH" => ENV.fetch("PATH", nil) }
    Open3.capture3(env, "ruby", exe, *args)
  end

  it "prints version" do
    out, _, status = run("version")
    expect(status.exitstatus).to eq(0)
    expect(out).to match(/^emfsvg \d/)
  end

  it "converts EMF to SVG" do
    Dir.mktmpdir do |dir|
      output = File.join(dir, "out.svg")
      _, err, status = run("convert", fixture, output)
      expect(status.exitstatus).to eq(0), "stderr: #{err[0, 500]}"
      expect(File.exist?(output)).to be true
      svg = File.read(output)
      expect(svg).to include("<svg")
      expect(svg).to include("</svg>")
    end
  end

  it "exits 2 when arguments are missing" do
    _, err, status = run("convert")
    expect(status.exitstatus).to eq(2)
    expect(err).to include("Usage:")
  end

  it "accepts --width and --height" do
    Dir.mktmpdir do |dir|
      output = File.join(dir, "out.svg")
      _, _, status = run("convert", "--width", "200", "--height", "100", fixture, output)
      expect(status.exitstatus).to eq(0)
      svg = File.read(output)
      expect(svg).to include(%(width="))
      expect(svg).to include(%(height="))
    end
  end

  it "to-emf writes EMF bytes from an SVG input" do
    Dir.mktmpdir do |dir|
      svg_in = File.join(dir, "input.svg")
      File.write(svg_in, '<svg width="100" height="50"></svg>')
      output = File.join(dir, "out.emf")
      _, _, status = run("to-emf", svg_in, output)
      expect(status.exitstatus).to eq(0)
      bytes = File.binread(output)
      expect(bytes.bytes[40, 4]).to eq([0x20, 0x45, 0x4D, 0x46])
    end
  end

  it "to-emf exits 2 when arguments are missing" do
    _, err, status = run("to-emf")
    expect(status.exitstatus).to eq(2)
    expect(err).to include("Usage:")
  end
end
