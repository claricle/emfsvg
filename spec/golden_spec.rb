# frozen_string_literal: true

require "spec_helper"
require "support/parity_corpus"

# Golden-master regression spec. Every pinned corpus input must byte-match
# its committed baseline under spec/fixtures/golden/. The manifest records
# the known provenance of those artifacts. Any drift fails.
#
# To update the golden set after an intentional change:
#   bundle exec ruby scripts/regenerate_golden.rb
#   git diff spec/fixtures/golden/   # review
#   git commit spec/fixtures/golden/

RSpec.describe "emfsvg golden master" do
  emf_paths = Emfsvg::SpecSupport::ParityCorpus.new.source_paths

  emf_paths.each do |emf|
    name = File.basename(emf, ".emf")
    golden_path = Emfsvg::SpecSupport::FixturePath.fixture("golden", "#{name}.svg")

    it "emfsvg output for #{name} matches golden baseline" do
      actual = Emfsvg.from_file(emf)
      expected = File.read(golden_path)
      expect(actual).to eq(expected),
                        -> { golden_diff(name, expected, actual) }
    end
  end

  def golden_diff(name, expected, actual)
    diff_offset = (0...[expected.bytesize, actual.bytesize].min)
                  .find { |i| expected.getbyte(i) != actual.getbyte(i) }
                  .to_s
    <<~MSG
      emfsvg output drifted for #{name}
        expected: #{expected.bytesize} bytes
        actual:   #{actual.bytesize} bytes
        first diff at byte offset: #{diff_offset}
      To update the golden: bundle exec ruby scripts/regenerate_golden.rb
    MSG
  end
end
