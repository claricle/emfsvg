# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Production conversion isolation" do
  include Emfsvg::SpecSupport::RuntimeIsolationFixture

  %w[supported unreadable resource_limited].each do |mode|
    context "with #{mode} bytes in a fresh process" do
      before(:context) do
        @observation = runtime_isolation_observation(mode)
      end

      it "returns the production result without invoking or loading the C reference" do
        if mode == "supported"
          expect(@observation.fetch("value_class")).to eq("String")
          expect(@observation.fetch("svg")).to include("<svg", "<rect")
          expect(@observation).not_to have_key("error_class")
        elsif mode == "unreadable"
          expect(@observation.fetch("error_class")).to eq("Emfsvg::ParseError")
          expect(@observation.fetch("error_message")).not_to be_empty
          expect(@observation).not_to have_key("svg")
        else
          expect(@observation.fetch("error_class")).to eq("Emfsvg::ResourceLimitError")
          expect(@observation.fetch("metadata")).to eq(["input_bytes", 23, 24])
          expect(@observation.fetch("cause_class")).to eq("Emf::ResourceLimitError")
          expect(@observation.fetch("cause_metadata")).to eq(["input_bytes", 23, 24])
          expect(@observation).not_to have_key("svg")
        end
        expect(@observation.fetch("sentinel_called")).to be(false)
        expect(@observation.fetch("forbidden_features")).to be_empty
      end

      it "has no libemf2svg library in the process mappings" do
        inspection = @observation.fetch("library_inspection")
        if inspection.fetch("status") == "unsupported"
          skip "Native library inspection unsupported: #{inspection.fetch('reason')}"
        end

        expect(inspection.fetch("status")).to eq("available")
        expect(inspection.fetch("method")).to match(%r{\A(?:/proc/self/maps|vmmap)\z})
        expect(inspection.fetch("forbidden_libraries")).to be_empty
      end
    end
  end
end
