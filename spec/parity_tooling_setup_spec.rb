# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Parity reporting tool setup" do
  include Emfsvg::SpecSupport::ParityToolingFixture

  %w[run_compat_check.rb run_round_trip.rb run_emf_svg_compare.rb].each do |script|
    context script do
      it "rejects a missing explicit corpus before conversion" do
        with_parity_tooling do |_root, project, _data, environment, probe, marker|
          environment["EMF_FIXTURE_ROOT"] = nil
          output, error, status = run_parity_tool(environment, project, probe, script)

          expect(status.success?).to be(false)
          expect(error).to include("EMF_FIXTURE_ROOT", "README.adoc")
          expect(output).not_to include("Total processed:", "Compatibility matrix", "Total fixtures:")
          expect(File.exist?(marker)).to be(false)
        end
      end

      it "rejects a corrupt unselected artifact before conversion" do
        with_parity_tooling do |root, project, data, environment, probe, marker|
          artifact = File.join(project, data.fetch("fixtures").last.fetch("round_trip").fetch("path"))
          File.write(artifact, "corrupt")
          arguments = if script == "run_compat_check.rb"
                        [File.join(root, "**",
                                   "#{data.fetch('fixtures').first.fetch('name')}.emf")]
                      else
                        ["1"]
                      end
          output, error, status = run_parity_tool(environment, project, probe, script, *arguments)

          expect(status.success?).to be(false)
          expect(error).to include("SHA-256 mismatch", artifact)
          expect(output).not_to include("Total processed:", "Compatibility matrix", "Total fixtures:")
          expect(File.exist?(marker)).to be(false)
        end
      end

      it "renders the selected pinned fixture with the real converter" do
        with_parity_tooling do |root, project, data, environment, probe, marker|
          materialize_tooling_conversions(root, project, data)
          arguments = if script == "run_compat_check.rb"
                        [File.join(root, "**",
                                   "#{data.fetch('fixtures').first.fetch('name')}.emf")]
                      else
                        ["1"]
                      end
          output, error, status = run_parity_tool(environment, project, probe, script, *arguments)

          expect(status.success?).to be(true), error
          if script == "run_round_trip.rb"
            expect(output).to include("Total processed:           1", "Total in golden set:       208",
                                      "Errors:                    0")
            expect(File.read(marker)).to eq("from_svg\n")
          else
            summary = if script == "run_compat_check.rb"
                        "Compatibility matrix (1 fixtures)"
                      else
                        "Total fixtures:           1"
                      end
            expect(output).to include(summary)
            expect(File.read(marker).lines.sort).to eq(%W[from_file\n reference\n])
          end
        end
      end
    end
  end

  reference_variables = %w[EMF2SVG_REF_PATH EMF2SVG_REF_LIB_DIR]
  %w[run_compat_check.rb run_emf_svg_compare.rb].each do |script|
    reference_variables.each do |variable|
      it "requires #{variable} before #{script} converts anything" do
        with_parity_tooling do |_root, project, _data, environment, probe, marker|
          environment[variable] = nil
          _output, error, status = run_parity_tool(environment, project, probe, script)

          expect(status.success?).to be(false)
          expect(error).to include(variable, "README.adoc")
          expect(File.exist?(marker)).to be(false)
        end
      end
    end
  end

  it "rejects an empty compatibility filter without reporting zero work" do
    with_parity_tooling do |_root, project, _data, environment, probe, marker|
      output, error, status = run_parity_tool(environment, project, probe, "run_compat_check.rb", "missing-*.emf")

      expect(status.success?).to be(false)
      expect(error).to include("No pinned fixtures match", "EMF_FIXTURE_ROOT")
      expect(output).not_to include("Compatibility matrix")
      expect(File.exist?(marker)).to be(false)
    end
  end

  %w[run_round_trip.rb run_emf_svg_compare.rb].each do |script|
    it "rejects a zero limit before #{script} converts anything" do
      with_parity_tooling do |_root, project, _data, environment, probe, marker|
        _output, error, status = run_parity_tool(environment, project, probe, script, "0")

        expect(status.success?).to be(false)
        expect(error).to include("limit must be positive")
        expect(File.exist?(marker)).to be(false)
      end
    end

    it "reports conversion failures from #{script} with a failing status" do
      with_parity_tooling do |_root, project, _data, environment, probe, marker|
        output, _error, status = run_parity_tool(environment, project, probe, script, "1")

        expect(status.success?).to be(false)
        expect(output).to include("Errors:                   ")
        expect(File.read(marker)).to eq(script == "run_round_trip.rb" ? "from_svg\n" : "from_file\n")
      end
    end
  end
end
