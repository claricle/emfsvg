# frozen_string_literal: true

require "cgi"
require "digest"
require "fontisan"
require "json"
require "open3"
require "rexml/document"
require "yaml"
require_relative "../../lib/emfsvg/glyph_index_mapper"

# Developer-only qualification: never installed or consulted by the runtime gem.
class FontQualification
  FONTCONFIG_FORMAT = format("%%{file}\\n").freeze
  STYLES = [false, true].freeze
  ROLES = %w[arial_regular arial_bold verdana_regular verdana_bold].freeze
  REQUIRED = {
    "Arial" => { 675 => 0x05D3, 674 => 0x05D2, 673 => 0x05D1, 672 => 0x05D0 },
    "David" => { 167 => 0x2248, 159 => 0x2126, 166 => 0x0192, 179 => 0x201C,
                 154 => 0x220F, 227 => 0x0161, 155 => nil, 163 => 0x00A1, 140 => 0x2122, 15 => 0x002C }
  }.freeze
  VECTORS = [
    ["Arial", [675, 674, 673, 672], "אבגד"],
    ["David", [167, 159, 166, 179], "“ƒΩ≈"],
    ["David", [154, 227, 155], ""],
    ["David", [163, 140, 155], ""],
    ["David", [15], ","]
  ].freeze

  def initialize(contract, ruby_only: false)
    @contract = contract
    @ruby_only = ruby_only
    @fonts = contract.fetch("fonts")
    ROLES.each do |role|
      font = @fonts.fetch(role)
      raise "Missing license provenance for #{role}" if font.fetch("license_provenance").strip.empty?

      check_hash(font.fetch("path"), font.fetch("sha256"))
    end
  end

  # No system configuration includes, and only explicitly supplied files allowed.
  # This can inspect licensed host files in place without copying their bytes.
  def configuration(cache)
    paths = ROLES.map { |role| File.realpath(@fonts.fetch(role).fetch("path")) }
    directories = paths.map { |path| File.dirname(path) }.uniq
    candidates = directories.flat_map { |path| Dir.glob(File.join(path, "**", "*")) }
    excluded = candidates.select { |path| File.file?(path) && !paths.include?(File.realpath(path)) }
    <<~XML
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig>
        #{directories.map { |path| "<dir>#{CGI.escapeHTML(path)}</dir>" }.join("\n")}
        <cachedir>#{CGI.escapeHTML(File.expand_path(cache))}</cachedir>
        <selectfont>
          <rejectfont>#{excluded.map { |path| "<glob>#{CGI.escapeHTML(path)}</glob>" }.join}</rejectfont>
        </selectfont>
        <match target="pattern">
          <test name="family" compare="eq"><string>David</string></test>
          <edit name="family" mode="assign" binding="strong"><string>Verdana</string></edit>
        </match>
      </fontconfig>
    XML
  end

  def probe
    raise "FONTCONFIG_FILE is required" unless File.file?(ENV.fetch("FONTCONFIG_FILE"))

    {
      "mode" => @ruby_only ? "ruby_only" : "full",
      "scope" => "#{@ruby_only ? 'Ruby' : 'Ruby and pinned C'} glyph vectors only; " \
                 "not full corpus or redistribution qualification",
      "platform" => RUBY_PLATFORM,
      "ruby_version" => RUBY_VERSION,
      "fontconfig_sha256" => Digest::SHA256.file(ENV.fetch("FONTCONFIG_FILE")).hexdigest,
      "fonts" => attest_fonts,
      "ruby_vectors" => ruby_vectors,
      "c_reference" => if @ruby_only
                         { "status" => "not_run", "reason" => "Ruby-only mode does not qualify C" }
                       else
                         native_vectors
                       end
    }
  end

  def attest_fonts
    listed = capture("fc-list", "-f", FONTCONFIG_FORMAT).lines.map(&:strip).reject(&:empty?).map do |path|
      File.realpath(path)
    end.uniq
    allowed = ROLES.map { |role| File.realpath(@fonts.fetch(role).fetch("path")) }.uniq
    raise "Fontconfig inventory differs from the four supplied fonts" unless listed.sort == allowed.sort

    { "Arial" => "arial", "David" => "verdana" }.flat_map do |family, prefix|
      STYLES.map do |bold|
        role = "#{prefix}_#{bold ? 'bold' : 'regular'}"
        pattern = bold ? "#{family}:weight=bold" : family
        path = capture("fc-match", "-f", FONTCONFIG_FORMAT, pattern).strip
        unless File.realpath(path) == File.realpath(@fonts.fetch(role).fetch("path"))
          raise "Wrong resolver candidate for #{pattern}: #{path}"
        end

        attest_font(role, family, pattern, path)
      end
    end
  end

  def attest_font(role, family, pattern, path)
    font = @fonts.fetch(role)
    check_hash(path, font.fetch("sha256"))
    cmap = cmap_bytes(path)
    cmap_sha = Digest::SHA256.hexdigest(cmap)
    raise "cmap checksum mismatch for #{role}" unless cmap_sha == font.fetch("cmap_sha256")

    forward = Fontisan::Tables::Cmap.read(cmap).unicode_mappings
    reverse = forward.each_with_object({}) do |(codepoint, glyph_id), mappings|
      # Last codepoint wins, matching FreeType's FT_Get_Next_Char behavior.
      mappings[glyph_id] = codepoint
    end

    mismatches = REQUIRED.fetch(family).reject { |gid, codepoint| reverse[gid] == codepoint }
    raise "Incompatible glyph mappings for #{role}: #{mismatches.inspect}" unless mismatches.empty?

    { "role" => role, "pattern" => pattern, "path" => File.realpath(path), "bytes" => File.size(path),
      "sha256" => Digest::SHA256.file(path).hexdigest, "cmap_sha256" => cmap_sha,
      "required_mappings" => REQUIRED.fetch(family), "license_provenance" => font.fetch("license_provenance") }
  end

  def ruby_vectors
    mapper = Emfsvg::GlyphIndexMapper.new
    VECTORS.map do |family, gids, expected|
      actual = mapper.map(gids, font_family: family, weight: 400, italic: 0, charset: 177)
      raise "Ruby vector differs for #{family} #{gids}: #{actual.inspect}" unless actual == expected

      { "family" => family, "glyph_ids" => gids, "weight" => 400, "italic" => 0, "charset" => 177, "output" => actual }
    end
  end

  def native_vectors
    native = @contract.fetch("c_reference")
    manifest = YAML.safe_load_file(File.expand_path("../../spec/fixtures/parity_manifest.yml", __dir__))
    pinned = manifest.fetch("provenance").fetch("c_reference")
    check_hash(native.fetch("binary"), pinned.fetch("binary_sha256"))
    check_hash(native.fetch("library"), pinned.fetch("library_sha256"))
    results = [183, 185].map { |number| native_fixture(number, native, manifest) }
    { "source_revision" => pinned.fetch("source_revision"), "binary_sha256" => pinned.fetch("binary_sha256"),
      "library_sha256" => pinned.fetch("library_sha256"), "fixtures" => results }
  end

  def native_fixture(number, native, manifest)
    name = "test-#{number}"
    entry = manifest.fetch("fixtures").find { |fixture| fixture.fetch("name") == name }
    input = File.join(@contract.fetch("corpus_root"), entry.fetch("source").fetch("path"))
    check_hash(input, entry.fetch("source").fetch("sha256"))
    output = File.join(@contract.fetch("output_directory"), "#{name}.svg")
    library_dir = File.dirname(File.expand_path(native.fetch("library")))
    capture({ "DYLD_LIBRARY_PATH" => library_dir, "LD_LIBRARY_PATH" => library_dir }, native.fetch("binary"), input,
            output)
    document = REXML::Document.new(File.binread(output))
    family = number == 183 ? "Arial" : "David"
    texts = REXML::XPath.match(document, "//*[local-name()='text']")
    actual = texts.select { |element| element.attributes["font-family"] == family }.map { |element| element.text.to_s }
    expected = number == 183 ? ["אבגד"] : ["“ƒΩ≈", "", "", ","]
    raise "Pinned C glyph vectors differ for #{name}: #{actual.inspect}" unless actual == expected

    { "name" => name, "input_sha256" => entry.fetch("source").fetch("sha256"), "glyph_text" => actual,
      "output_sha256" => Digest::SHA256.file(output).hexdigest }
  end

  private

  def capture(*command)
    stdout, stderr, status = Open3.capture3(*command)
    raise "Command failed: #{command.inspect}: #{stderr}" unless status.success?

    stdout
  end

  def check_hash(path, expected)
    raise "Invalid SHA256 for #{path}" unless /\A[0-9a-f]{64}\z/.match?(expected)
    raise "File checksum mismatch for #{path}" unless Digest::SHA256.file(path).hexdigest == expected
  end

  def cmap_bytes(path)
    bytes = File.binread(path)
    count = bytes[4, 2].unpack1("n")
    count.times do |index|
      offset = 12 + (index * 16)
      next unless bytes[offset, 4] == "cmap"

      start, length = bytes[offset + 8, 8].unpack("NN")
      return bytes[start, length]
    end
    raise "Missing cmap: #{path}"
  end
end
