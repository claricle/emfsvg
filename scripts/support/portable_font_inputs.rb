# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "net/http"
require "open3"
require "tmpdir"

# Downloads intact licensed installers; never installs fonts system-wide or runs EXEs.
class PortableFontInputs
  DOWNLOAD_ATTEMPTS = 3
  TRANSIENT_DOWNLOAD_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout].freeze
  INSTALLERS = {
    "arial32.exe" => "85297a4d146e9c87ac6f74822734bdee5f4b2a722d7eaa584b7f2cbf76f478f6",
    "verdan32.exe" => "c1cb61255e363166794e47664e2f21af8e3a26cb6346eb8d2ae2fa85dd5aad96"
  }.freeze
  FONTS = {
    "arial_regular" => ["arial32.exe", "Arial.TTF", "35c0f3559d8db569e36c31095b8a60d441643d95f59139de40e23fada819b833",
                        "a48fa82b57546837c3c8e54fc66331bb3183f4c2605ee73fa41ecbd3b3c866ab"],
    "arial_bold" => ["arial32.exe", "Arialbd.TTF", "4044aa6b5bebbc36980206b45b0aaaaa5681552a48bcadb41746d5d1d71fd7b4",
                     "a48fa82b57546837c3c8e54fc66331bb3183f4c2605ee73fa41ecbd3b3c866ab"],
    "verdana_regular" => ["verdan32.exe", "Verdana.TTF",
                          "96ed14949ca4b7392cff235b9c41d55c125382abbe0c0d3c2b9dd66897cae0cb",
                          "702194f24f99b6f185dae25f86aab6ad697645db7f29f765b0ab51ebce054739"],
    "verdana_bold" => ["verdan32.exe", "Verdanab.TTF",
                       "c8f5065ba91680f596af3b0378e2c3e713b95a523be3d56ae185ca2b8f5f0b23",
                       "2f8ca49a89bbf59b77ad89111689cbfc70356f4a0f5f393f8aedecd70cbca54d"]
  }.freeze
  SUPPLIER = "https://phoenixnap.dl.sourceforge.net/project/corefonts/the%20fonts/final/"
  LICENSE = "Original Microsoft corefonts installers from #{SUPPLIER}; accompanying Microsoft EULA " \
            "(https://corefonts.sourceforge.net/eula.htm) permits installation/use. " \
            "Installer SHA256 verified before local extraction; no extracted-font redistribution grant claimed.".freeze

  def initialize(options, downloader: method(:download), extractor: nil)
    @options = options
    @downloader = downloader
    @extractor = extractor
  end

  def provision
    validate_paths
    tool = find_extractor unless @extractor
    contract = nil
    # A fresh directory keeps partial or preexisting fonts out of the emitted inventory.
    directory = Dir.mktmpdir("corefonts-", @options.fetch("staging_directory"))
    begin
      installers = provision_installers(directory)
      fonts = extract_fonts(directory, installers, tool)
      contract = @options.slice("corpus_root", "output_directory", "c_reference").merge("fonts" => fonts)
      write_contract(contract)
    rescue StandardError
      FileUtils.remove_entry(directory)
      raise
    end
    contract
  end

  private

  def validate_paths
    %w[staging_directory corpus_root].each do |key|
      path = absolute_path(@options.fetch(key), key)
      raise "Missing directory for #{key}: #{path}" unless File.directory?(path)
    end
    if @options.key?("c_reference")
      %w[binary library].each do |key|
        path = absolute_path(@options.fetch("c_reference").fetch(key), "c_reference.#{key}")
        raise "Missing reference #{key}: #{path}" unless File.file?(path)
      end
    end
    absolute_path(@options.fetch("output_directory"), "output_directory")
    path = absolute_path(@options.fetch("contract_path"), "contract_path")
    raise "Missing contract parent: #{path}" unless File.directory?(File.dirname(path))
    raise "Contract path already exists: #{path}" if File.exist?(path) || File.symlink?(path)
    return unless @options.key?("installers_directory")

    path = absolute_path(@options.fetch("installers_directory"), "installers_directory")
    raise "Missing installers directory: #{path}" unless File.directory?(path)
  end

  def absolute_path(path, label)
    raise "Expected absolute path for #{label}" unless path.is_a?(String) && File.absolute_path(path) == path

    path
  end

  def find_extractor
    names = %w[7zz 7z 7zz.exe 7z.exe]
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |directory|
      names.each do |name|
        path = File.join(directory, name)
        return path if File.file?(path) && File.executable?(path)
      end
    end
    raise "Missing extractor: install 7z or 7zz and add it to PATH"
  end

  def provision_installers(directory)
    INSTALLERS.to_h do |name, sha|
      path = File.join(@options.fetch("installers_directory", directory), name)
      download_installer("#{SUPPLIER}#{name}", path) unless @options.key?("installers_directory")
      verify_hash(path, sha)
      [name, path]
    end
  end

  def download_installer(url, path)
    attempts = 0
    begin
      @downloader.call(url, path)
    rescue *TRANSIENT_DOWNLOAD_ERRORS
      attempts += 1
      retry if attempts < DOWNLOAD_ATTEMPTS

      raise
    end
  end

  def extract_fonts(directory, installers, tool)
    fonts_directory = File.join(directory, "fonts")
    FileUtils.mkdir(fonts_directory)
    FONTS.to_h do |role, (installer, entry, sha, cmap_sha)|
      path = File.join(fonts_directory, entry)
      if @extractor
        @extractor.call(installers.fetch(installer), entry, path)
      else
        extract(tool, installers.fetch(installer), entry, path)
      end
      verify_hash(path, sha)
      [role, { "path" => path, "sha256" => sha, "cmap_sha256" => cmap_sha, "license_provenance" => LICENSE }]
    end
  end

  def verify_hash(path, sha)
    raise "Missing input file: #{path}" unless File.file?(path)
    raise "SHA256 mismatch: #{path}" unless Digest::SHA256.file(path).hexdigest == sha
  end

  def extract(tool, installer, entry, destination)
    # Only one pinned entry is streamed; the archive never chooses filesystem paths.
    stdout, stderr, status = Open3.capture3(tool, "e", "-so", installer, entry, binmode: true)
    raise "Extraction failed for #{entry}: #{stderr}" unless status.success?
    raise "Missing font entry: #{entry}" if stdout.empty?

    File.binwrite(destination, stdout)
  end

  def write_contract(contract)
    # EXCL preserves existing evidence and rejects symlinks rather than overwriting it.
    File.open(@options.fetch("contract_path"), File::WRONLY | File::CREAT | File::EXCL) do |file|
      file.write(JSON.pretty_generate(contract))
    end
  end

  def download(url, path, redirects = 5)
    uri = URI(url)
    raise "Download requires HTTPS: #{url}" unless uri.is_a?(URI::HTTPS)

    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
      http.request_get(uri.request_uri) do |response|
        case response
        when Net::HTTPSuccess
          File.open(path, "wb") { |file| response.read_body { |chunk| file.write(chunk) } }
        when Net::HTTPRedirection
          raise "Too many download redirects" if redirects.zero?

          download(URI.join(url, response.fetch("location")).to_s, path, redirects - 1)
        else
          raise "Download failed: HTTP #{response.code} for #{url}"
        end
      end
    end
  end
end
