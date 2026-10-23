# frozen_string_literal: true

require_relative "parity_corpus"
require_relative "golden_regeneration"
require_relative "golden_regeneration_fixture"

if $PROGRAM_NAME == __FILE__
  mode, *arguments = ARGV
  if mode == "lock"
    path = File.join(File.realpath(arguments.fetch(0)), ".golden-regeneration.lock")
    File.open(path, File::RDWR | File::CREAT, 0o600) do |lock|
      raise "fixture lock unavailable" unless lock.flock(File::LOCK_EX | File::LOCK_NB)

      $stdout.sync = true
      puts "locked"
      $stdin.read
      raise Emfsvg::SpecSupport::GoldenRegeneration::Error, "synthetic lock failure"
    end
  else
    fixture = Object.new.extend(Emfsvg::SpecSupport::GoldenRegenerationFixture)
    runner = fixture.regeneration_runner(*arguments, $stdout)
    exit(runner.run(check: true) ? 0 : 1)
  end
end
