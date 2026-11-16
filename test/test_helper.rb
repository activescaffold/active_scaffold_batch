# frozen_string_literal: true

if ENV['COVERAGE'] == 'true'
  require 'simplecov'
  SimpleCov.start
end
require 'minitest/autorun'
