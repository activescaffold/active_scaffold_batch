require 'active_scaffold_batch/engine'
require 'active_scaffold_batch/version'

module ActiveScaffoldBatch
  def self.root
    File.dirname(__FILE__) + "/.."
  end
end

module ActiveScaffold
  module Actions
    ActiveScaffold.autoload_subdir('actions', self, File.dirname(__FILE__))
  end

  module Config
    ActiveScaffold.autoload_subdir('config', self, File.dirname(__FILE__))
  end

  module Helpers
    ActiveScaffold.autoload_subdir('helpers', self, File.dirname(__FILE__))
  end
end

ActiveScaffold.stylesheets << 'active_scaffold_batch'
ActiveScaffold.javascripts << 'active_scaffold_batch'
