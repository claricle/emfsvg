# frozen_string_literal: true

# Usage: bundle exec ruby scripts/qualify_fonts.rb CONTRACT.json
# See scripts/support/font_qualification.md for the external input contract.
require "fileutils"
require "rbconfig"
require_relative "support/font_qualification"

if $PROGRAM_NAME == __FILE__
  begin
    contract_path = ARGV.fetch(0)
    contract = JSON.parse(File.read(contract_path))
    directory = File.expand_path(contract.fetch("output_directory"))
    FileUtils.mkdir_p(directory)
    report = File.join(directory, "qualification.json")
    FileUtils.rm_f(report) unless ARGV[1] == "--probe"
    qualifier = FontQualification.new(contract)
    configuration = File.join(directory, "fonts.conf")
    if ARGV[1] == "--probe"
      puts JSON.pretty_generate(qualifier.probe)
    else
      File.write(configuration, qualifier.configuration(File.join(directory, "cache")))
      env = { "FONTCONFIG_FILE" => configuration, "FONTCONFIG_PATH" => directory }
      stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, __FILE__, contract_path, "--probe")
      File.write(report, stdout) if status.success?
      $stdout.write(stdout)
      $stderr.write(stderr)
      exit status.exitstatus
    end
  rescue StandardError => e
    warn "Font qualification failed: #{e.message}"
    exit 1
  end
end
