# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "open3"
require_relative "../scripts/support/source_qualification_probe"

RSpec.describe Emfsvg::SourceQualificationProbe do
  let(:revision) { "a" * 40 }
  let(:root) { Dir.mktmpdir("emf-source-probe") }
  let(:source) { Bundler::Source::Git.allocate }
  let(:loaded) { double("loaded Git emf", source: source, version: Gem::Version.new("0.1.3"), full_gem_path: root) }
  let(:locked) { double("locked Git emf", name: "emf", source: source) }
  let(:function) { instance_double(Fiddle::Function, call: 1) }
  let(:features) { $LOADED_FEATURES }
  let(:git) do
    lambda do |*arguments|
      output, status = Open3.capture2("git", "-C", root, *arguments)
      raise output unless status.success?

      output.strip
    end
  end

  before do
    git.call("init", "--quiet")
    git.call("config", "user.email", "probe@example.test")
    git.call("config", "user.name", "Probe")
    FileUtils.mkdir_p(File.join(root, "lib"))
    File.write(File.join(root, "lib/emf.rb"), "# source probe fixture\n")
    git.call("add", "lib/emf.rb")
    git.call("commit", "--quiet", "-m", "fixture")
    allow(source).to receive_messages(uri: described_class::SOURCE_URI, ref: revision, revision: revision)
    allow(Bundler).to receive(:read_file).with("fixture.lock").and_return("lock")
    allow(Bundler::LockfileParser).to receive(:new).with("lock").and_return(double(specs: [locked]))
    allow(Gem).to receive(:loaded_specs).and_return("emf" => loaded)
    allow(Fiddle).to receive(:dlopen).with("fixture.so").and_return(double("native library", :[] => 42))
    allow(Fiddle::Function).to receive(:new).with(42, [], Fiddle::TYPE_INT).and_return(function)
    allow(features).to receive(:find).and_call_original
    allow(features).to receive(:find).with(any_args).and_return(File.join(root, "lib/emf.rb"))
  end

  after { FileUtils.remove_entry(root) }

  it "qualifies the exact locked, loaded, clean Git source and required native exports" do
    actual_revision = git.call("rev-parse", "HEAD")
    allow(source).to receive(:revision).and_return(actual_revision)
    allow(source).to receive(:ref).and_return(actual_revision)
    value = described_class.call("fixture.lock", "fixture.so", actual_revision)

    expect(value).to include("root" => File.realpath(root), "source_revision" => actual_revision, "abi" => "1")
    expect(value.fetch("entrypoint")).to eq(File.realpath(File.join(root, "lib/emf.rb")))
    expect(value.fetch("sha256")).to eq(Digest::SHA256.file(value.fetch("entrypoint")).hexdigest)
    expect(value.fetch("ruby_tree_sha256")).to match(/\A[0-9a-f]{64}\z/)
    expect(function).to have_received(:call)
  end

  it "rejects stale lock and loaded revisions before probing native code" do
    allow(source).to receive(:revision).and_return("b" * 40)
    expect { described_class.call("fixture.lock", "fixture.so", revision) }
      .to raise_error(/expected Git source revision/)
    expect(Fiddle).not_to have_received(:dlopen)
  end

  it "rejects a shadowed entrypoint and a dirty tracked checkout" do
    shadow = File.join(root, "shadow/emf.rb")
    FileUtils.mkdir_p(File.dirname(shadow))
    File.write(shadow, "# shadow\n")
    allow(features).to receive(:find).and_return(shadow)
    expect { described_class.call("fixture.lock", "fixture.so", revision) }.to raise_error(/shadowed/)
    allow(features).to receive(:find).and_return(File.join(root, "lib/emf.rb"))
    File.write(File.join(root, "lib/emf.rb"), "modified\n")
    actual_revision = git.call("rev-parse", "HEAD")
    allow(source).to receive_messages(ref: actual_revision, revision: actual_revision)
    expect { described_class.call("fixture.lock", "fixture.so", actual_revision) }
      .to raise_error(/tracked tree is dirty/)
  end

  it "requires the expected revision to be a full lowercase SHA" do
    expect { described_class.call("fixture.lock", "fixture.so", "short") }.to raise_error(/full lowercase Git SHA/)
  end
end
