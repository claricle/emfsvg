# frozen_string_literal: true

# Usage: bundle exec ruby scripts/qualify_fonts.rb [--ruby-only] CONTRACT.json
# See scripts/support/font_qualification.md for the external input contract.
require "fileutils"
require "optparse"
require "rbconfig"
require_relative "support/font_qualification"

if $PROGRAM_NAME == __FILE__
  begin
    options = { ruby_only: false, probe: false }
    OptionParser.new do |parser|
      parser.on("--ruby-only") { options[:ruby_only] = true }
      parser.on("--probe") { options[:probe] = true }
    end.parse!(ARGV)
    raise ArgumentError, "Expected one contract path" unless ARGV.size == 1

    contract_path = ARGV.fetch(0)
    contract = JSON.parse(File.read(contract_path))
    directory = File.expand_path(contract.fetch("output_directory"))
    FileUtils.mkdir_p(directory)
    report = File.join(directory, "qualification.json")
    FileUtils.rm_f(report) unless options[:probe]
    qualifier = FontQualification.new(contract, ruby_only: options[:ruby_only])
    configuration = File.join(directory, "fonts.conf")
    if options[:probe]
      puts JSON.pretty_generate(qualifier.probe)
    else
      File.write(configuration, qualifier.configuration(File.join(directory, "cache")))
      env = { "FONTCONFIG_FILE" => configuration, "FONTCONFIG_PATH" => directory }
      arguments = [contract_path, "--probe"]
      arguments << "--ruby-only" if options[:ruby_only]
      stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, __FILE__, *arguments)
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
