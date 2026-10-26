# frozen_string_literal: true

require_relative "support/released_qualification"
require_relative "support/released_native_archive"

if $PROGRAM_NAME == __FILE__
  begin
    mode, manifest, input, library, provenance = ARGV
    required_arguments = mode == "native" ? 5 : 3
    unless ARGV.size == required_arguments
      raise Emfsvg::ReleasedQualification::Rejected,
            "usage: plan|archive|acceptance MANIFEST INPUT, or native MANIFEST PACKAGE LIBRARY PROVENANCE"
    end

    result = case mode
             when "plan" then Emfsvg::ReleasedQualification.plan(manifest, input)
             when "native" then Emfsvg::ReleasedNativeArchive.extract!(manifest, input, library, provenance)
             when "archive" then Emfsvg::ReleasedQualification.archive!(manifest, input)
             when "acceptance" then Emfsvg::ReleasedQualification.acceptance!(manifest, input)
             else raise Emfsvg::ReleasedQualification::Rejected, "unknown release qualification mode"
             end
    puts JSON.generate(result)
  rescue Emfsvg::ReleasedQualification::Rejected, SystemCallError, Psych::Exception, Gem::Package::Error => e
    warn "Released qualification rejected: #{e.message}"
    exit 1
  end
end
