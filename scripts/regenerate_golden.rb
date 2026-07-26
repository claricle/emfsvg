# frozen_string_literal: true

# Regenerates both golden fixture sets:
#   spec/fixtures/golden/<name>.svg        — libemf2svg reference output
#   spec/fixtures/emfsvg_golden/<name>.svg — emfsvg current output
#
# Usage:
#   bundle exec ruby scripts/regenerate_golden.rb
#
# Requires libemf2svg's emf2svg_ref binary at ../libemf2svg/emf2svg_ref.
# See spec/fixtures/README.md for build instructions.

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../spec", __dir__))
require "emfsvg"
require "support/emfsvg_compat"
require "fileutils"

EMF_GLOBS = %w[
  ../emf/spec/fixtures/emf/*.emf
  ../emf/spec/fixtures/emf-ea/*.emf
  ../emf/spec/fixtures/simple/*.emf
].freeze

REF_DIR = File.expand_path("../spec/fixtures/golden", __dir__)
EMFSVG_DIR = File.expand_path("../spec/fixtures/emfsvg_golden", __dir__)

FileUtils.mkdir_p(REF_DIR)
FileUtils.mkdir_p(EMFSVG_DIR)

ref_ok = ref_fail = emfsvg_ok = emfsvg_fail = 0

EMF_GLOBS.each do |glob|
  Dir.glob(glob).each do |emf|
    name = File.basename(emf, ".emf")
    ref_path = File.join(REF_DIR, "#{name}.svg")
    emfsvg_path = File.join(EMFSVG_DIR, "#{name}.svg")

    # libemf2svg reference
    begin
      svg = Emfsvg::Compat.generate_reference(emf, ref_path)
      if svg
        File.binwrite(ref_path, svg)
        ref_ok += 1
      else
        ref_fail += 1
      end
    rescue StandardError
      ref_fail += 1
    end

    # emfsvg current
    begin
      svg = Emfsvg.from_file(emf)
      File.write(emfsvg_path, svg)
      emfsvg_ok += 1
    rescue StandardError
      emfsvg_fail += 1
    end
  end
end

puts "libemf2svg golden: #{ref_ok} ok, #{ref_fail} failed"
puts "emfsvg golden:     #{emfsvg_ok} ok, #{emfsvg_fail} failed"
puts "Reference dir:    #{REF_DIR}"
puts "emfsvg dir:       #{EMFSVG_DIR}"
