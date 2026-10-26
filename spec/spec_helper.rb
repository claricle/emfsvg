# frozen_string_literal: true

require "emfsvg"

Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.filter_run_excluding live_reference: true unless ENV["EMFSVG_LIVE_REFERENCE"] == "1"
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = "doc" if config.files_to_run.one?

  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed
end

module Emfsvg
  module SpecSupport
    module FixturePath
      module_function

      def fixtures_root
        File.expand_path("fixtures", __dir__)
      end

      def fixture(*parts)
        File.join(fixtures_root, *parts)
      end

      def read_fixture(*parts)
        File.read(fixture(*parts), mode: "rb")
      end
    end
  end
end
