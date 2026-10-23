# frozen_string_literal: true

require "digest"

module Emfsvg
  module SpecSupport
    module ParityComparison
      module_function

      def difference(group:, name:, reference:, expected:, actual:)
        offset = (0...[expected.bytesize, actual.bytesize].min).find do |index|
          expected.getbyte(index) != actual.getbyte(index)
        end
        offset ||= [expected.bytesize, actual.bytesize].min if expected.bytesize != actual.bytesize
        preview_start = [offset.to_i - 24, 0].max
        <<~MESSAGE
          #{group}: #{name}; reference=#{reference}
          generated SHA-256=#{Digest::SHA256.hexdigest(actual)}
          expected=#{expected.bytesize} bytes; generated=#{actual.bytesize} bytes; first difference=#{offset.inspect}
          expected excerpt=#{expected.byteslice(preview_start, 80).inspect}
          generated excerpt=#{actual.byteslice(preview_start, 80).inspect}
        MESSAGE
      end

      def inventory_digest(rows)
        Digest::SHA256.hexdigest(rows.sort_by(&:first).map { |row| "#{row.join("\t")}\n" }.join)
      end

      def artifact_inventory(corpus, kinds)
        rows = corpus.fixtures.map do |entry|
          hashes = kinds.map do |kind|
            path = kind == "source" ? corpus.source_path(entry) : corpus.artifact_path(entry, kind)
            Digest::SHA256.file(path).hexdigest
          end
          [entry.fetch("name"), *hashes]
        end
        inventory_digest(rows)
      end

      def c_provenance_errors(provenance)
        errors = []
        unless provenance.fetch("status") == "verified"
          errors << "status must be verified (got #{provenance.fetch('status').inspect})"
        end
        unless /\A[0-9a-f]{40}\z/.match?(provenance.fetch("source_revision").to_s)
          errors << "source_revision must be a full commit SHA"
        end
        %w[reported_version build_recipe generation_command].each do |field|
          errors << "#{field} must be recorded" if provenance.fetch(field).to_s.strip.empty?
        end
        expected_options = { "nameSpace" => nil, "verbose" => 0, "emfplus" => 1,
                             "svgDelimiter" => 1, "imgWidth" => 0, "imgHeight" => 0 }
        unless provenance.fetch("wrapper_options") == expected_options
          errors << "wrapper_options differ from the C oracle recipe"
        end
        errors
      end
    end
  end
end
