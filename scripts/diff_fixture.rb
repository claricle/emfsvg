#!/usr/bin/env ruby
# frozen_string_literal: true

# One-off diff tool: dumps the first N children of each side to
# highlight where input and round-trip output diverge.
#
# Usage: bundle exec ruby scripts/diff_fixture.rb <fixture.svg>

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../spec", __dir__))
require "emfsvg"
require "nokogiri"

path = ARGV[0] or abort "usage: #{$PROGRAM_NAME} <fixture.svg>"
svg = File.read(path)
emf = Emfsvg.from_svg(svg)
result = Emfsvg.from_bytes(emf)

in_doc = Nokogiri::XML(svg, &:noblanks).tap(&:remove_namespaces!)
out_doc = Nokogiri::XML(result, &:noblanks).tap(&:remove_namespaces!)

[in_doc, out_doc].each { |d| d.search("//defs").each(&:remove) }

in_g = in_doc.root.at_xpath("g")
out_g = out_doc.root.at_xpath("g")

def attr_summary(elem)
  elem.attributes.keys.sort.map { |k| "#{k}=#{elem.attributes[k].value[0, 30]}" }.join(" ")
end

puts "input g children: #{in_g.element_children.size}"
puts "output g children: #{out_g.element_children.size}"
puts

max = [in_g.element_children.size, out_g.element_children.size].min
diffs_seen = 0
(0...max).each do |i|
  a = in_g.element_children[i]
  b = out_g.element_children[i]
  next unless a.name != b.name || a.attributes.keys != b.attributes.keys

  puts "[#{i}] IN : <#{a.name} #{attr_summary(a)}>"
  puts "[#{i}] OUT: <#{b.name} #{attr_summary(b)}>"
  puts
  diffs_seen += 1
  break if diffs_seen >= 5
end

puts "Extra in OUTPUT (after position #{max}):" if in_g.element_children.size < out_g.element_children.size
(max...out_g.element_children.size).first(5).each do |i|
  b = out_g.element_children[i]
  puts "[#{i}] OUT: <#{b.name} #{attr_summary(b)}>"
end
