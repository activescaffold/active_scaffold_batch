# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'active_scaffold_batch/version'

Gem::Specification.new do |s|
  s.name = "active_scaffold_batch"
  s.version = ActiveScaffoldBatch::Version::STRING
  s.platform = Gem::Platform::RUBY
  s.homepage = "http://github.com/scambra/active_scaffold_batch"
  s.license = "MIT"
  s.summary = %Q{Batch Processing for ActiveScaffold}
  s.description = %Q{You want to destroy/update many records at once with activescaffold?}
  s.email = "activescaffold@googlegroups.com"
  s.authors = ["Sergio Cambra", "Volker Hochstein"]
  s.require_paths = ["lib"]
  s.files = `git ls-files {app,config,lib,vendor}`.split($/) + %w[LICENSE.txt README]
  s.extra_rdoc_files = [
    "README"
  ]
  s.test_files = `git ls-files test`.split("\n")

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.add_development_dependency(%q<bundler>, ["~> 1.0"])
  s.add_runtime_dependency 'active_scaffold', '>= 3.7.1'
end

