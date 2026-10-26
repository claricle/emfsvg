# frozen_string_literal: true

# Spec-only utility: structurally compares emfsvg's output against
# libemf2svg's reference output for the same EMF input. Used by
# spec/compat_with_libemf2svg_spec.rb and scripts/regenerate_golden.rb.
#
# This is NOT shipped in the gem. Lives under spec/support/ and loaded
# only when running the test suite or developer scripts.
#
# Usage:
#   Emfsvg::Compat.compare_glob(fixtures_glob)
#
# Live reference generation requires explicit EMF2SVG_REF_PATH and
# EMF2SVG_REF_LIB_DIR. See spec/fixtures/README.adoc for setup.

require "open3"
require "tmpdir"
require "rexml/document"

module Emfsvg
  module Compat
    class SetupError < StandardError; end
    class ConversionError < StandardError; end

    module_function

    def validate_reference!
      binary = ENV.fetch("EMF2SVG_REF_PATH", nil)
      lib_dir = ENV.fetch("EMF2SVG_REF_LIB_DIR", nil)
      unless binary && File.file?(binary) && File.executable?(binary)
        raise SetupError,
              "Set EMF2SVG_REF_PATH to the executable pinned C reference wrapper; see spec/fixtures/README.adoc"
      end
      unless lib_dir && File.directory?(lib_dir)
        raise SetupError,
              "Set EMF2SVG_REF_LIB_DIR to the pinned C reference library directory; see spec/fixtures/README.adoc"
      end

      [File.expand_path(binary), File.expand_path(lib_dir)]
    end

    def ref_binary_available?
      validate_reference!
      true
    rescue SetupError
      false
    end

    # Explicit output paths are retained; internally allocated directories are
    # removed on both successful generation and failure.
    def generate_reference(emf_path, output_path = nil)
      binary, lib_dir = validate_reference!
      Dir.mktmpdir("emfsvg-reference-") do |directory|
        temporary_output = File.join(directory, "reference.svg")
        env = { "DYLD_LIBRARY_PATH" => lib_dir, "LD_LIBRARY_PATH" => lib_dir }
        _, stderr, status = Open3.capture3(env, binary, emf_path.to_s, temporary_output)
        raise ConversionError, "C reference failed for #{emf_path} (#{status}): #{stderr.strip}" unless status.success?
        unless File.file?(temporary_output) && File.size?(temporary_output)
          raise ConversionError, "C reference produced no SVG for #{emf_path}; check the wrapper and library setup"
        end

        svg = File.binread(temporary_output)
        File.binwrite(output_path, svg) if output_path
        svg
      end
    rescue SystemCallError => e
      raise ConversionError, "C reference could not convert #{emf_path}: #{e.message}"
    end

    # Generate emfsvg output. Requires the emfsvg gem to be loaded.
    def generate_emfsvg(emf_path, options = {})
      Emfsvg.from_file(emf_path, **options)
    end

    # Normalise an SVG document for structural comparison:
    # - parse to REXML
    # - return the root element
    def parse_svg(svg_string)
      REXML::Document.new(svg_string).root
    rescue REXML::ParseException
      nil
    end

    # Count drawing elements in an SVG. Returns a hash like
    # { "rect" => 3, "path" => 17, "ellipse" => 2 }.
    def count_elements(svg_root)
      counts = Hash.new(0)
      return counts unless svg_root

      REXML::XPath.each(svg_root, "descendant-or-self::*") do |el|
        counts[el.name] += 1
      end
      counts
    end

    # Per-fixture comparison result.
    Result = Struct.new(:fixture, :ref_bytes, :emfsvg_bytes, :ref_elements,
                        :emfsvg_elements, keyword_init: true) do
      def byte_ratio
        ref_bytes.zero? ? 0.0 : (emfsvg_bytes.to_f / ref_bytes * 100).round(1)
      end

      def element_overlap
        return 0.0 if emfsvg_elements.empty?

        shared = emfsvg_elements.keys & ref_elements.keys
        shared.sum { |k| [emfsvg_elements[k], ref_elements[k]].min }.to_f /
          emfsvg_elements.values.sum
      end

      def to_s
        format("%<fixture>-40s ref=%<ref>8d out=%<out>7d (%<ratio>5.1f%%) elements_overlap=%<overlap>.1f",
               fixture: fixture, ref: ref_bytes, out: emfsvg_bytes, ratio: byte_ratio,
               overlap: element_overlap * 100)
      end
    end

    # Walk a fixtures glob, produce both outputs, return Result array.
    def compare_glob(fixtures_glob)
      results = []
      Dir.glob(fixtures_glob).each do |emf|
        ref_svg = generate_reference(emf)
        emfsvg_svg = generate_emfsvg(emf)

        results << Result.new(
          fixture: File.basename(emf),
          ref_bytes: ref_svg.bytesize,
          emfsvg_bytes: emfsvg_svg.bytesize,
          ref_elements: count_elements(parse_svg(ref_svg)),
          emfsvg_elements: count_elements(parse_svg(emfsvg_svg))
        )
      end
      results
    end

    # Summary across many results.
    def summarize(results)
      return "no results" if results.empty?

      total_ref = results.sum(&:ref_bytes)
      total_out = results.sum(&:emfsvg_bytes)
      ratio = total_ref.zero? ? 0 : (total_out.to_f / total_ref * 100).round(1)
      avg_overlap = results.sum(&:element_overlap) / results.size
      format("fixtures=%<count>d  total_ref=%<ref>d  total_out=%<out>d  " \
             "byte_ratio=%<ratio>.1f%%  avg_element_overlap=%<overlap>.1f%%",
             count: results.size, ref: total_ref, out: total_out, ratio: ratio, overlap: avg_overlap * 100)
    end
  end
end
