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

      def qualification_cli(contract, directory, *options)
        contract["output_directory"] = directory
        contract_path = File.join(directory, "contract.json")
        File.write(contract_path, JSON.generate(contract))
        commands = File.join(directory, "commands")
        FileUtils.mkdir_p(commands)
        fonts = contract.fetch("fonts").transform_values { |font| font.fetch("path") }
        resolver = <<~RUBY
          #!#{RbConfig.ruby}
          require "json"
          fonts = JSON.parse(#{JSON.generate(fonts).inspect})
          abort "Missing isolated configuration" unless File.file?(ENV.fetch("FONTCONFIG_FILE"))
          if File.basename($PROGRAM_NAME) == "fc-list"
            puts fonts.values
          else
            prefix = ARGV.last.start_with?("Arial") ? "arial" : "verdana"
            style = ARGV.last.include?("weight=bold") ? "bold" : "regular"
            puts fonts.fetch("\#{prefix}_\#{style}")
          end
        RUBY
        %w[fc-list fc-match].each do |name|
          path = File.join(commands, name)
          File.write(path, resolver)
          FileUtils.chmod(0o755, path)
          File.write("#{path}.bat", "@echo off\r\n\"#{RbConfig.ruby}\" \"#{path}\" %*\r\n") if File::ALT_SEPARATOR
        end
        script = File.expand_path("../../scripts/qualify_fonts.rb", __dir__)
        Open3.capture3({ "PATH" => "#{commands}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}" },
                       RbConfig.ruby, script, contract_path, *options)
      end
    end
  end
end
