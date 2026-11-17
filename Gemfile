# frozen_string_literal: true

source 'http://rubygems.org'
# Add dependencies required to use your gem here.
# Example:
#   gem "activesupport", ">= 2.3.5"

gemspec

# TODO: Remove this override when ActiveScaffold 4.5 is released with plugin JavaScript test support.
gem 'active_scaffold', github: 'activescaffold/active_scaffold', branch: 'master'
gem 'simplecov', '~> 1.3', require: false

group :test do
  gem 'capybara'
  gem 'jquery-rails'
  gem 'propshaft'
  gem 'puma'
  gem 'selenium-webdriver'
end
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
