module ActiveScaffoldBatch
  class Engine < ::Rails::Engine
    initializer 'active_scaffold_batch.routes' do
      ActiveSupport.on_load :active_scaffold_routing do
        self::ACTIVE_SCAFFOLD_CORE_ROUTING[:collection][:batch_edit] = :get
        self::ACTIVE_SCAFFOLD_CORE_ROUTING[:collection][:batch_update] = :post
        self::ACTIVE_SCAFFOLD_CORE_ROUTING[:collection][:batch_new] = :get
        self::ACTIVE_SCAFFOLD_CORE_ROUTING[:collection][:batch_create] = :post
        self::ACTIVE_SCAFFOLD_CORE_ROUTING[:collection][:batch_add] = :get
        #not working because routing picks show route instead
        #self::ACTIVE_SCAFFOLD_CORE_ROUTING[:collection][:batch_destroy] = :get
        #you may define a route for your controller before resource routes
        #match 'players/batch_destroy' => 'players#batch_destroy', :via => [:get]
        self::ACTIVE_SCAFFOLD_CORE_ROUTING[:collection][:batch_destroy] = :delete
      end
    end

    initializer("active_scaffold_batch.view") do
      ActiveSupport.on_load(:action_view) do
        begin
          include ActiveScaffold::Helpers::UpdateColumnHelpers
          include ActiveScaffold::Helpers::DatepickerUpdateColumnHelpers
          include ActiveScaffold::Helpers::BatchCreateColumnHelpers
        rescue
          raise $! unless Rails.env == 'production'
        end
      end
    end
  end
end
