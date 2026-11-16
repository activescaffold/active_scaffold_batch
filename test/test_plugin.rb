# frozen_string_literal: true

require 'test_helper'
require 'active_scaffold/extensions/routing_mapper'

class PluginTest < Minitest::Test
  def test_entry_point_registers_assets_ui_element_and_root
    assert_includes ActiveScaffold.stylesheets, 'active_scaffold_batch'
    assert_includes ActiveScaffold.javascripts, 'active_scaffold_batch'
    assert_equal({attributes: {}}, ActiveScaffold.ui_elements[:batch_create_add_rows])
    assert_equal File.expand_path('..', __dir__), File.expand_path(ActiveScaffoldBatch.root)
  end

  def test_extensions_load_batch_actions_configurations_and_helpers
    expected_sources = {
      ActiveScaffold::Actions::BatchCreate.instance_method(:batch_create) =>
        'lib/active_scaffold/actions/batch_create.rb',
      ActiveScaffold::Config::BatchCreate.instance_method(:action_group) =>
        'lib/active_scaffold/config/batch_create.rb',
      ActiveScaffold::Helpers::BatchCreateColumnHelpers.instance_method(:batch_create_multiple_layout) =>
        'lib/active_scaffold/helpers/batch_create_column_helpers.rb'
    }

    expected_sources.each do |method, relative_path|
      assert_equal File.expand_path("../#{relative_path}", __dir__), method.source_location.first
    end
  end

  def test_engine_defines_named_initializers
    assert_equal %w[active_scaffold_batch.routes active_scaffold_batch.view],
                 ActiveScaffoldBatch::Engine.initializers.map(&:name)
  end

  def test_routes_initializer_registers_batch_routes
    run_initializer('active_scaffold_batch.routes')

    routes = ActiveScaffold::Routing::ACTIVE_SCAFFOLD_CORE_ROUTING.fetch(:collection)
    assert_equal :get, routes[:batch_edit]
    assert_equal :post, routes[:batch_update]
    assert_equal :get, routes[:batch_new]
    assert_equal :post, routes[:batch_create]
    assert_equal :get, routes[:batch_add]
    assert_equal :delete, routes[:batch_destroy]
  end

  def test_view_initializer_installs_all_batch_helpers
    run_initializer('active_scaffold_batch.view')

    assert_includes ActionView::Base.ancestors, ActiveScaffold::Helpers::UpdateColumnHelpers
    assert_includes ActionView::Base.ancestors, ActiveScaffold::Helpers::DatepickerUpdateColumnHelpers
    assert_includes ActionView::Base.ancestors, ActiveScaffold::Helpers::BatchCreateColumnHelpers
  end

  private

  def run_initializer(name)
    ActiveScaffoldBatch::Engine.initializers.find { |initializer| initializer.name == name }.run
  end
end
