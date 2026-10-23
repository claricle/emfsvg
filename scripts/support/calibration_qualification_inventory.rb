# frozen_string_literal: true

require "digest"
require "json"
require_relative "corrupt_outcome_contract"

module Emfsvg
  module ResourceCalibration
    # These fingerprints pin source identities and valid output identities, never
    # corrupt outputs. Reviewed corrupt expectations come from the separate ledger.
    class QualificationInventory
      VALID_IDENTITY = "97cd02735266cbee236f3849cfb8f81a98dfdd3dc6a2d7caac0013d05c3d6b54"
      CORRUPT_IDENTITY = "d28727fcb122effa4f3c64fc92f16b28d7d9326294c2d49a23a2403f6efc2cf2"

      attr_reader :inputs

      def initialize(manifest, ledger)
        valid = manifest.fetch("fixed_sample").map do |name|
          matches = manifest.fetch("fixtures").select { |entry| entry.fetch("name") == name }
          raise Rejected, "valid control inventory mismatch" unless matches.one?

          matches.first.slice("name", "source", "round_trip")
        end
        corrupt = manifest.fetch("corrupted").map do |entry|
          entry.slice("name", "source")
        end
        corrupt.sort_by! { |entry| entry.fetch("name") }
        check_identity!(valid, VALID_IDENTITY, 9)
        check_identity!(corrupt, CORRUPT_IDENTITY, 21)
        @contract = CorruptOutcomeContract.new(manifest: manifest, ledger: ledger)
        unless @contract.report.fetch("counts") == { "contracted" => 21, "matched" => 0, "unresolved" => 0,
                                                     "mismatch" => 0 }
          raise Rejected, "21 independently reviewed corrupt outcomes are required"
        end

        @inputs = valid.map do |entry|
          input(entry, { "kind" => "svg", "warnings" => [], "svg_sha256" => entry.dig("round_trip", "sha256") })
        end + corrupt.map { |entry| input(entry, ledger.fetch(entry.fetch("name")).fetch("expected_outcome")) }
      end

      private

      def check_identity!(entries, expected, count)
        return if entries.size == count && Digest::SHA256.hexdigest(JSON.generate(entries)) == expected

        raise Rejected, "exact pinned calibration inventory mismatch"
      end

      def input(entry, expected)
        { "name" => entry.dig("source", "path"), "sha256" => entry.dig("source", "sha256"),
          "expected_outcome" => expected }
      end
    end
  end
end
