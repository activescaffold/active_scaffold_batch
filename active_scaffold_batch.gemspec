# frozen_string_literal: true

require 'English'

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'active_scaffold_batch/version'

Gem::Specification.new do |s|
  s.name = 'active_scaffold_batch'
  s.version = ActiveScaffoldBatch::Version::STRING
  s.platform = Gem::Platform::RUBY
  s.homepage = 'http://github.com/scambra/active_scaffold_batch'
  s.license = 'MIT'
  s.summary = %(Batch Processing for ActiveScaffold)
  s.description = %(You want to destroy/update many records at once with activescaffold?)
  s.email = 'activescaffold@googlegroups.com'
  s.authors = ['Sergio Cambra', 'Volker Hochstein']
  s.require_paths = ['lib']
  s.files = `git ls-files {app,config,lib,vendor}`.split($INPUT_RECORD_SEPARATOR) + %w[LICENSE.txt README]
  s.extra_rdoc_files = [
    'README'
  ]

  s.required_ruby_version = '>= 3.2'
  s.add_dependency 'active_scaffold', '>= 4.4.6'
  s.metadata['rubygems_mfa_required'] = 'true'
end
