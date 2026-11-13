# frozen_string_literal: true

require 'active_scaffold_batch/engine'
require 'active_scaffold_batch/extensions'
require 'active_scaffold_batch/version'

module ActiveScaffoldBatch
  def self.root
    "#{File.dirname(__FILE__)}/.."
  end
end

ActiveScaffold.stylesheets << 'active_scaffold_batch'
ActiveScaffold.javascripts << 'active_scaffold_batch'
ActiveScaffold.set_element :batch_create_add_rows, attributes: {}
