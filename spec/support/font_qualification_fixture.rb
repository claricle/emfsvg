# frozen_string_literal: true

require "tmpdir"
require "fileutils"

module Emfsvg
  module SpecSupport
    module FontQualificationFixture
      def qualification_font(path, mappings)
        groups = mappings.compact.sort_by(&:last)
        subtable = [12, 0, 16 + (12 * groups.size), 0, groups.size].pack("nnNNN")
        subtable << groups.map { |gid, codepoint| [codepoint, codepoint, gid].pack("NNN") }.join
        cmap = [0, 1, 3, 10, 12].pack("nnnnN") + subtable
        font = "#{[0x00010000, 1, 0, 0, 0].pack('Nnnnn')}cmap#{[0, 28, cmap.bytesize].pack('NNN')}#{cmap}"
        File.binwrite(path, font)
        { "path" => path, "sha256" => Digest::SHA256.hexdigest(font), "cmap_sha256" => Digest::SHA256.hexdigest(cmap),
          "license_provenance" => "Synthetic test cmap; no third-party font bytes." }
      end

      def qualification_contract(directory)
        fonts = FontQualification::ROLES.to_h do |role|
          family = role.start_with?("arial") ? "Arial" : "David"
          [role, qualification_font(File.join(directory, "#{role}.ttf"), FontQualification::REQUIRED.fetch(family))]
        end
        { "fonts" => fonts }
      end
    end
  end
end
