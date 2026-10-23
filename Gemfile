# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Temporary development integration for the upstream #15 model contract.
# Replace with a qualified release once a released tag contains this revision.
gem "emf", git: "https://github.com/claricle/emf.git", ref: "56c5ec1aae9fb7682b0a05a3e493d1997839e0c4"

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
gem "leptris", ">= 1.9.365.1"
