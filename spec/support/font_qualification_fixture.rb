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

      def qualification_resolver(fonts)
        <<~RUBY
          #!#{RbConfig.ruby}
          require "json"
          fonts = JSON.parse(#{JSON.generate(fonts).inspect})
          abort "Missing isolated configuration" unless File.file?(ENV.fetch("FONTCONFIG_FILE"))
          if File.basename($PROGRAM_NAME) == "fc-list"
            puts fonts.values
          else
            File.open(File.join(File.dirname($PROGRAM_NAME), "fc-match-argv.log"), "a") do |log|
              log.puts(JSON.generate(ARGV))
            end
            if ENV["FONTCONFIG_BATCH_SIMULATION"] == "1" && ARGV[1]&.include?("\n")
              abort "Fontconfig format contains a literal newline"
            end
            pattern = ARGV.find { |argument| argument.start_with?("Arial", "David") }
            abort "Unexpected fc-match argv: \#{ARGV.inspect}" unless pattern

            prefix = pattern.start_with?("Arial") ? "arial" : "verdana"
            style = pattern&.include?("weight=bold") ? "bold" : "regular"
            puts fonts.fetch("\#{prefix}_\#{style}")
          end
        RUBY
      end

      def qualification_cli(contract, directory, *options)
        contract["output_directory"] = directory
        contract_path = File.join(directory, "contract.json")
        File.write(contract_path, JSON.generate(contract))
        commands = File.join(directory, "commands")
        FileUtils.mkdir_p(commands)
        FileUtils.rm_f(File.join(commands, "fc-match-argv.log"))
        fonts = contract.fetch("fonts").transform_values { |font| font.fetch("path") }
        resolver = qualification_resolver(fonts)
        %w[fc-list fc-match].each do |name|
          path = File.join(commands, name)
          File.write(path, resolver)
          FileUtils.chmod(0o755, path)
          File.write("#{path}.bat", "@echo off\r\n\"#{RbConfig.ruby}\" \"#{path}\" %*\r\n") if File::ALT_SEPARATOR
        end
        script = File.expand_path("../../scripts/qualify_fonts.rb", __dir__)
        stdout, stderr, status = Open3.capture3({ "PATH" => "#{commands}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}",
                                                  "FONTCONFIG_BATCH_SIMULATION" => "1" },
                                                RbConfig.ruby, script, contract_path, *options)
        argv_log = File.join(commands, "fc-match-argv.log")
        stderr = "#{stderr}\nfc-match argv: #{File.read(argv_log)}" if !status.success? && File.file?(argv_log)
        [stdout, stderr, status]
      end
    end
  end
end
