# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rake", "~> 13.0"

group :development do
  gem "rexml", "~> 3.3"
  gem "rspec", "~> 3.13"
  gem "rspec-collection_matchers"
  gem "rubocop", "~> 1.65"
  gem "rubocop-performance", "~> 1.21"
end

# Always-available for development scripts and tests; gemspec declares
# the runtime dep that ships to consumers.
gem "leptris"
