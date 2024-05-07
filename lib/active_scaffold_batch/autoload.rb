module ActiveScaffold
  module Actions
    ActiveScaffold.autoload_subdir('actions', self, ActiveScaffoldBatch.root + '/lib')
  end

  module Config
    ActiveScaffold.autoload_subdir('config', self, ActiveScaffoldBatch.root + '/lib')
  end

  module Helpers
    ActiveScaffold.autoload_subdir('helpers', self, ActiveScaffoldBatch.root + '/lib')
  end
end
