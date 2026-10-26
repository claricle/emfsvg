# frozen_string_literal: true

require "spec_helper"
require_relative "../scripts/support/calibration_qualification_probe"

RSpec.describe Emfsvg::ResourceCalibration::QualificationProbe do
  let(:source) { Bundler::Source::Rubygems.allocate }
  let(:version) { Gem::Version.new("1.2.3") }
  let(:runtime) { Gem.loaded_specs.fetch("emf") }
  let(:root) { runtime.full_gem_path }
  let(:loaded) { Struct.new(:source, :version, :full_gem_path).new(source, version, root) }
  let(:locked) { Struct.new(:source, :version, :name).new(source, version, "emf") }
  let(:function) { instance_double(Fiddle::Function, call: 1) }

  before do
    allow(Bundler).to receive(:read_file).with("fixture.lock").and_return("controlled parsed lock")
    allow(Bundler::LockfileParser).to receive(:new).with("controlled parsed lock").and_return(
      Struct.new(:specs).new([locked])
    )
    original = Gem.loaded_specs.dup
    allow(Gem).to receive(:loaded_specs).and_return(original.merge("emf" => loaded))
    allow(Fiddle).to receive(:dlopen).with("fixture.so").and_return("emf_abi_version" => 42)
    allow(Fiddle::Function).to receive(:new).with(42, [], Fiddle::TYPE_INT).and_return(function)
  end

  it "requires a matching released lock and loaded gem and observes the ABI export" do
    value = described_class.call("fixture.lock", "fixture.so")
    expect(value).to include("root" => File.realpath(root), "version" => "1.2.3", "abi" => "1")
    expect(value.fetch("entrypoint")).to eq(File.realpath(File.join(root, "lib/emf.rb")))
    expect(value.fetch("sha256")).to eq(Digest::SHA256.file(value.fetch("entrypoint")).hexdigest)
    expect(function).to have_received(:call)
  end

  it "rejects a Git or path source on either side of the lock/load boundary" do
    [locked, loaded].each do |spec|
      allow(spec).to receive(:source).and_return(Bundler::Source::Git.allocate)
      expect { described_class.call("fixture.lock", "fixture.so") }.to raise_error(/same released Rubygems/)
      allow(spec).to receive(:source).and_return(source)
    end
    expect(Fiddle).not_to have_received(:dlopen)
  end

  it "rejects lock/load version mismatches and duplicate locked entries" do
    allow(locked).to receive(:version).and_return(Gem::Version.new("1.2.4"))
    expect { described_class.call("fixture.lock", "fixture.so") }.to raise_error(/same released Rubygems/)
    allow(locked).to receive(:version).and_return(version)
    allow(Bundler::LockfileParser).to receive(:new).and_return(Struct.new(:specs).new([locked, locked]))
    expect { described_class.call("fixture.lock", "fixture.so") }.to raise_error(/same released Rubygems/)
  end

  it "rejects a loaded entrypoint outside the released gem root before probing native code" do
    Dir.mktmpdir do |directory|
      allow(loaded).to receive(:full_gem_path).and_return(directory)
      expect { described_class.call("fixture.lock", "fixture.so") }.to raise_error(/shadowed emf entrypoint/)
    end
    expect(Fiddle).not_to have_received(:dlopen)
  end

  it "does not substitute another native symbol when the ABI export is unavailable" do
    allow(Fiddle).to receive(:dlopen).and_raise(Fiddle::DLError, "missing emf_abi_version")
    expect { described_class.call("fixture.lock", "fixture.so") }.to raise_error(Fiddle::DLError, /emf_abi_version/)
  end
end
