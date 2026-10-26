# frozen_string_literal: true

require_relative "support/released_qualification"

if $PROGRAM_NAME == __FILE__
  begin
    mode, manifest, input = ARGV
    raise Emfsvg::ReleasedQualification::Rejected, "usage: plan|archive|acceptance MANIFEST INPUT" unless ARGV.size == 3

    result = case mode
             when "plan" then Emfsvg::ReleasedQualification.plan(manifest, input)
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
