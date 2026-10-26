# frozen_string_literal: true

require_relative "../../scripts/support/source_qualification"

module Emfsvg
  module SpecSupport
    module SourceQualificationFixture
      include CalibrationQualificationFixture

      def source_qualification_fixture
        qualification_fixture(Dir.mktmpdir)
        stub_const("Emfsvg::ResourceCalibration::SourceQualification::RUBY_PLATFORM", "x86_64-linux")
        @manifest.fetch("provenance").fetch("runtime").merge!("status" => "unqualified", "source" => "git",
                                                              "package_sha256" => nil)
        write_qualification_evidence
        @mutate_report = lambda do |value, request|
          next unless request.fetch(:basename) == "source-runtime-identity"

          value.merge!("root" => @runtime_root, "source_revision" => REVISION,
                       "ruby_tree_sha256" => Emfsvg::SourceQualificationProbe.ruby_tree_sha256(@runtime_root))
        end
      end

      def controlled_qualification_report(request)
        if request.fetch(:basename) == "source-runtime-identity"
          return super(request.merge(basename: "runtime-identity"))
        end

        super
      end

      def qualify_source
        Emfsvg::ResourceCalibration::SourceQualification.new(
          manifest: @manifest_path, fixture_root: @directory, native_library: @native_path,
          native_provenance_path: @native_provenance, lockfile: @lockfile, runner: @runner
        ).verify!
      end
    end
  end
end
