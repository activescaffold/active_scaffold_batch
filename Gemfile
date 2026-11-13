# frozen_string_literal: true

source 'http://rubygems.org'
# Add dependencies required to use your gem here.
# Example:
#   gem "activesupport", ">= 2.3.5"

gemspec
# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.
group :development do
  gem 'rake'
  gem 'rdoc'
end

group :lint do
  gem 'rubocop', '~> 1.86.0', require: false
  gem 'rubocop-erb', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
end
