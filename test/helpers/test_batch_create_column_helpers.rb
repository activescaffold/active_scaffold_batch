# frozen_string_literal: true

require 'minitest/autorun'

module ActiveScaffold
  module Helpers
  end
end

require_relative '../../lib/active_scaffold/helpers/batch_create_column_helpers'

class BatchCreateColumnHelpersTest < Minitest::Test
  Columns = Struct.new(:visible_columns_names)
  ActionConfig = Struct.new(:layout, :columns)
  Config = Struct.new(:batch_create, :batch_update)

  class BaseHelper
    attr_accessor :parent_columns

    def current_form_columns(*)
      parent_columns
    end
  end

  class Helper < BaseHelper
    include ActiveScaffold::Helpers::BatchCreateColumnHelpers

    attr_accessor :action_name
    attr_reader :active_scaffold_config

    def initialize
      super
      @active_scaffold_config = Config.new(
        ActionConfig.new(:horizontal, Columns.new([:name])),
        ActionConfig.new(nil, Columns.new([:status]))
      )
    end
  end

  def test_layout_partial_comes_from_configuration
    assert_equal 'batch_create_form_horizontal', Helper.new.batch_create_multiple_layout
  end

  def test_create_actions_use_batch_create_columns
    helper = Helper.new
    helper.action_name = 'batch_create'

    assert_equal [:name], helper.current_form_columns(nil, nil)
  end

  def test_update_actions_use_batch_update_columns
    helper = Helper.new
    helper.action_name = 'batch_edit'

    assert_equal [:status], helper.current_form_columns(nil, nil)
  end

  def test_parent_columns_take_precedence
    helper = Helper.new
    helper.action_name = 'batch_create'
    helper.parent_columns = [:custom]

    assert_equal [:custom], helper.current_form_columns(nil, nil)
  end
end
