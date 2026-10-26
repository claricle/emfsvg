# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Temporary development integration for the upstream model, diagnostics, and
# resources contracts. Replace with a qualified release once one contains them.
gem "emf", git: "https://github.com/claricle/emf.git", ref: "e0491ed331dff6c5996dcbd9a269b79ffebbcc38"

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
