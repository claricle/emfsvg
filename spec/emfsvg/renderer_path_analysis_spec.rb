# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::Renderer do
  let(:renderer) { described_class.allocate }
  let(:records_module) { Emf::Emr::Binary::Records }

  def record_for(name)
    Struct.new(:wire).new(records_module.const_get(name).new)
  end

  def analyse(names)
    renderer.send(:build_path_analysis, names.map { |name| record_for(name) })
  end

  # The action rule from the path pre-pass: the first of Fill / Stroke /
  # StrokeAndFill / Abort after a BeginPath decides it; another BeginPath
  # first, or none at all, means :end.
  def reference_action(names, start)
    names[(start + 1)..].each do |name|
      case name
      when "FillPath" then return :fill
      when "StrokePath" then return :stroke
      when "StrokeAndFillPath" then return :stroke_fill
      when "AbortPath" then return :abort
      when "BeginPath" then return :end
      end
    end
    :end
  end

  describe "#build_path_analysis path actions" do
    it "resolves each BeginPath to the first path-painting record after it" do
      names = %w[BeginPath LineTo EndPath FillPath BeginPath EndPath StrokePath
                 BeginPath EndPath StrokeAndFillPath BeginPath AbortPath BeginPath EndPath]
      actions, = analyse(names)
      expect(actions).to eq(0 => :fill, 4 => :stroke, 7 => :stroke_fill, 10 => :abort, 12 => :end)
    end

    it "gives :end to a BeginPath followed by another BeginPath before any painting" do
      actions, = analyse(%w[BeginPath BeginPath FillPath])
      expect(actions).to eq(0 => :end, 1 => :fill)
    end

    it "matches the forward-scan rule on random record sequences" do
      rng = Random.new(11)
      vocabulary = %w[BeginPath EndPath FillPath StrokePath StrokeAndFillPath AbortPath LineTo Polygon16]
      50.times do
        names = Array.new(rng.rand(0..40)) { vocabulary.sample(random: rng) }
        actions, = analyse(names)
        expected = names.each_index.select { |i| names[i] == "BeginPath" }
                        .to_h { |i| [i, reference_action(names, i)] }
        expect(actions).to eq(expected)
      end
    end
  end

  describe "#build_path_analysis path transforms" do
    it "splits in-path transforms into before and after the first drawing record" do
      _, transforms = analyse(%w[BeginPath SetWorldTransform LineTo ModifyWorldTransform EndPath])
      expect(transforms[0][:wt_after].mode).to eq(0)
      expect(transforms[0][:wt_before]).to be_a(described_class::PathTransform)
    end

    it "ignores transforms outside a path" do
      _, transforms = analyse(%w[SetWorldTransform BeginPath EndPath])
      expect(transforms[1]).to eq(wt_before: nil, wt_after: nil)
    end
  end
end
