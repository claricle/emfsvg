# frozen_string_literal: true

# Usage: bundle exec ruby scripts/provision_qualification_fonts.rb OPTIONS.json
# Required absolute paths: staging_directory (existing), corpus_root (existing),
# output_directory, contract_path (new), c_reference: {binary:, library:} (existing).
# Optional installers_directory reuses locally downloaded, hash-pinned EXEs.
# Requires 7z/7zz on PATH. Accept the installers' accompanying Microsoft corefonts
# EULA before use: https://corefonts.sourceforge.net/eula.htm. No fonts are bundled.
require_relative "support/portable_font_inputs"

if $PROGRAM_NAME == __FILE__
  begin
    options = JSON.parse(File.read(ARGV.fetch(0)))
    PortableFontInputs.new(options).provision
    puts options.fetch("contract_path")
  rescue StandardError => e
    warn "Font provisioning failed: #{e.message}"
    exit 1
  end
end
