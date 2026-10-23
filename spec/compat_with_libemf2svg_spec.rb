# frozen_string_literal: true

require "spec_helper"
require "support/parity_corpus"
require "support/parity_comparison"

# Committed C artifacts are the oracle; ordinary specs never invoke live C.
RSpec.describe "emfsvg vs libemf2svg reference" do
  corpus = Emfsvg::SpecSupport::ParityCorpus.new
  corpus.verify!
  comparison = Emfsvg::SpecSupport::ParityComparison

  describe "for every fixture" do
    corpus.fixtures.each do |entry|
      name = entry.fetch("name")
      source = corpus.source_path(entry)
      reference = corpus.artifact_path(entry, "golden")

      it "#{name}.emf matches C bytes" do
        expected = File.binread(reference)
        actual = Emfsvg.from_file(source)
        message = lambda do
          comparison.difference(group: "ruby_to_c_golden", name: name, reference: reference,
                                expected: expected, actual: actual)
        end
        expect(actual.b == expected).to be(true), message
      end

      it "#{name}.emf C artifact matches SHA-256 and verified provenance" do
        aggregate_failures do
          expect(Digest::SHA256.file(reference).hexdigest).to eq(entry.fetch("golden").fetch("sha256"))
          errors = comparison.c_provenance_errors(corpus.manifest.fetch("provenance").fetch("c_reference"))
          expect(errors).to be_empty, "c_artifact_integrity: #{name}; reference=#{reference}; #{errors.join('; ')}"
        end
      end
    end
  end

  describe "fixed historical sample" do
    entries = corpus.fixtures.to_h { |entry| [entry.fetch("name"), entry] }
    corpus.manifest.fetch("fixed_sample").each do |name|
      entry = entries.fetch(name)
      reference = corpus.artifact_path(entry, "golden")

      it "#{name}.emf matches C bytes and contains valid SVG elements" do
        expected = File.binread(reference)
        actual = Emfsvg.from_file(corpus.source_path(entry))
        aggregate_failures do
          message = lambda do
            comparison.difference(group: "fixed_sample", name: name, reference: reference,
                                  expected: expected, actual: actual)
          end
          expect(actual.b == expected).to be(true), message
          root = Emfsvg::Compat.parse_svg(actual)
          expect(root).not_to be_nil
          if root
            valid = %w[svg g path rect ellipse line polyline polygon circle text image defs clipPath clippath use]
            expect(Emfsvg::Compat.count_elements(root).keys - valid).to be_empty
          end
        end
      end
    end
  end

  it "matches the exact sorted source/reference/generated output inventory" do
    inventory = corpus.manifest.fetch("inventories")
    expect(inventory.fetch("compatibility_columns")).to eq(%w[source golden generated])
    rows = corpus.fixtures.map do |entry|
      source = corpus.source_path(entry)
      reference = corpus.artifact_path(entry, "golden")
      [entry.fetch("name"), Digest::SHA256.file(source).hexdigest, Digest::SHA256.file(reference).hexdigest,
       Digest::SHA256.hexdigest(Emfsvg.from_file(source))]
    end
    expect(comparison.inventory_digest(rows)).to eq(inventory.fetch("compatibility_sha256"))
  end
end
