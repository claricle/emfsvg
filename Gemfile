# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Pin the reviewed released source package; Linux native qualification verifies
# its separately published platform archive against the parity manifest.
gem "emf", "0.2.0", force_ruby_platform: true

gem "rake", "~> 13.0"

group :development do
  gem "fiddle", "~> 1.1"
  gem "rexml", "~> 3.3"
  gem "rspec", "~> 3.13"
  gem "rspec-collection_matchers"
  gem "rubocop", "~> 1.65"
  gem "rubocop-performance", "~> 1.21"
end

# Always-available for development scripts and tests; gemspec declares
# the runtime dep that ships to consumers.
gem "leptris", ">= 1.9.365.1"
