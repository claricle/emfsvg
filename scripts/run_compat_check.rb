# frozen_string_literal: true

# Walks every EMF fixture, generates both libemf2svg reference output
# and emfsvg's output, and reports a compatibility matrix.
#
# Usage:
#   bundle exec ruby scripts/run_compat_check.rb [fixtures_glob]
#
# Default fixtures_glob: ../emf/spec/fixtures/**/*.emf
#
# Requires the libemf2svg binary at ../libemf2svg/emf2svg_ref
# (built via `cmake -S . -B build -DLONLY=ON && make -C build`).

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "emfsvg"
require "emfsvg/compat"

glob = ARGV[0] || File.expand_path("../emf/spec/fixtures/**/*.emf", __dir__)
results = Emfsvg::Compat.compare_glob(glob)

puts "Compatibility matrix (#{results.size} fixtures)"
puts "=" * 80
puts "Fixture                                    ref(B)  out(B)    ratio  element_overlap"
puts "-" * 80
results.each { |r| puts r }
puts "=" * 80
puts Emfsvg::Compat.summarize(results)
