require 'active_scaffold_batch/engine'
require 'active_scaffold_batch/version'

module ActiveScaffoldBatch
  def self.root
    File.dirname(__FILE__) + "/.."
  end
end
