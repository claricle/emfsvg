# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::ReleasedQualification do
  include Emfsvg::SpecSupport::ReleasedQualificationFixture

  around do |example|
    Dir.mktmpdir("released-qualification-spec-") do |directory|
      @directory = directory
      @manifest_path = File.join(directory, "manifest.yml")
      @lockfile = File.join(directory, "Gemfile.lock")
      @report_path = File.join(directory, "rspec.json")
      @manifest = release_manifest
      write_release_manifest(@manifest)
      write_release_lock
      example.run
    end
  end

  it "derives the exact Rubygems archive and corpus from reviewed inputs" do
    expect(described_class.plan(@manifest_path, @lockfile)).to eq(
      "package_url" => "https://rubygems.org/downloads/emf-9.8.7.gem",
      "native_package_url" => "https://rubygems.org/downloads/emf-9.8.7-x86_64-linux-gnu.gem",
      "corpus_revision" => @manifest.dig("provenance", "corpus", "revision")
    )
  end

  it "rejects source qualification without treating it as a released package" do
    @manifest.fetch("provenance").fetch("runtime").merge!("status" => "unqualified", "source" => "git")
    write_release_manifest(@manifest)
    expect { described_class.plan(@manifest_path, @lockfile) }
      .to raise_error(described_class::Rejected, /reviewed released manifest required/)
  end

  it "rejects a Git lock even when version and source revision match" do
    runtime = @manifest.fetch("provenance").fetch("runtime")
    write_release_lock("GIT\n  remote: https://github.com/claricle/emf.git\n  " \
                       "revision: #{runtime.fetch('source_revision')}\n")
    expect { described_class.plan(@manifest_path, @lockfile) }
      .to raise_error(described_class::Rejected, /lock must select/)
  end

  it "rejects an alternate package registry and a mismatched locked version" do
    write_release_lock("GEM\n  remote: https://example.invalid/\n")
    expect { described_class.plan(@manifest_path, @lockfile) }.to raise_error(described_class::Rejected)
    write_release_lock
    File.write(@lockfile, File.read(@lockfile).sub("9.8.7", "9.8.8"))
    expect { described_class.plan(@manifest_path, @lockfile) }.to raise_error(described_class::Rejected)
  end

  it "requires the Ruby source package independently of the native package" do
    File.write(@lockfile, File.read(@lockfile).sub("emf (9.8.7)", "emf (9.8.7-x86_64-linux-gnu)"))
    expect { described_class.plan(@manifest_path, @lockfile) }
      .to raise_error(described_class::Rejected, /lock must select/)
  end

  it "requires actual archive bytes and archive source metadata, preserving reviewed inputs on rejection" do
    archive = build_release_archive
    expect(described_class.archive!(@manifest_path, archive)).to eq("emf-9.8.7")
    @manifest.fetch("provenance").fetch("runtime")["source_revision"] = "e" * 40
    write_release_manifest(@manifest)
    before = File.binread(@manifest_path)
    expect { described_class.archive!(@manifest_path, archive) }
      .to raise_error(described_class::Rejected, /must attest/)
    expect(File.binread(@manifest_path)).to eq(before)
    File.open(archive, "a") { |file| file.write("drift") }
    expect { described_class.archive!(@manifest_path, archive) }
      .to raise_error(described_class::Rejected, /SHA mismatch/)
  end

  it "rejects archives lacking source revision metadata despite an exact package SHA" do
    archive = build_release_archive(nil)
    expect { described_class.archive!(@manifest_path, archive) }
      .to raise_error(described_class::Rejected, /must attest/)
  end

  it "accepts complete passing evidence without rewriting the report or manifest" do
    write_release_report(release_report)
    before = [File.binread(@manifest_path), File.binread(@report_path)]
    expect(described_class.acceptance!(@manifest_path, @report_path)).to be(true)
    expect([File.binread(@manifest_path), File.binread(@report_path)]).to eq(before)
  end

  it "rejects a skipped corrupt qualification even if the summary claims success" do
    report = release_report
    example = report.fetch("examples").find { |entry| entry["description"] == described_class::CORRUPT_EXAMPLE }
    example["status"] = "pending"
    write_release_report(report)
    expect { described_class.acceptance!(@manifest_path, @report_path) }
      .to raise_error(described_class::Rejected, /every example passed/)
  end

  it "rejects omitted real corpus execution despite enough synthetic examples" do
    report = release_report
    example = report.fetch("examples").find { |entry| entry["description"] == described_class::CORRUPT_EXAMPLE }
    example["description"] = "other"
    write_release_report(report)
    expect { described_class.acceptance!(@manifest_path, @report_path) }
      .to raise_error(described_class::Rejected, /real corrupted corpus/)
  end

  it "rejects omitted golden coverage despite an unchanged whole-suite count" do
    report = release_report
    report.fetch("examples").first["file_path"] = "./spec/other_spec.rb"
    write_release_report(report)
    expect { described_class.acceptance!(@manifest_path, @report_path) }
      .to raise_error(described_class::Rejected, /golden acceptance count drift/)
  end

  it "rejects incomplete, duplicate and failed result reports" do
    %w[summary examples].each do |field|
      write_release_report(release_report.reject { |key, _value| key == field })
      expect { described_class.acceptance!(@manifest_path, @report_path) }.to raise_error(described_class::Rejected)
    end
    report = release_report
    report.fetch("examples").last["id"] = report.fetch("examples").first.fetch("id")
    write_release_report(report)
    expect { described_class.acceptance!(@manifest_path, @report_path) }.to raise_error(described_class::Rejected)
    report = release_report
    report.fetch("summary")["errors_outside_of_examples_count"] = 1
    write_release_report(report)
    expect { described_class.acceptance!(@manifest_path, @report_path) }.to raise_error(described_class::Rejected)
  end
end
