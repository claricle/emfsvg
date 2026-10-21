# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emfsvg::Translation::RecordEmitter do
  it "sets n_size to the serialized byte length of a variable-size record" do
    points = [{ x: 1, y: 2 }, { x: 3, y: 4 }, { x: 5, y: 6 }]
    record = described_class.new.build(
      Emf::Emr::Binary::Records::Polygon,
      i_type: 3, rcl_bounds: { left: 0, top: 0, right: 9, bottom: 9 },
      cptl: points.size, aptl: points
    )
    expect(record.wire.n_size).to eq(record.wire.to_binary_s.bytesize)
  end
end
