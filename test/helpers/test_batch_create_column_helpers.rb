# frozen_string_literal: true

require 'test_helper'

module ActiveScaffold
  module Helpers
  end
end

require_relative '../../lib/active_scaffold/helpers/batch_create_column_helpers'

class BatchCreateColumnHelpersTest < Minitest::Test
  Column = Struct.new(:name, :form_ui, :form_ui_options, :options, :association)
  Record = Struct.new(:id)
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

    attr_accessor :action_name, :parent_columns
    attr_reader :active_scaffold_config, :calls, :params

    def initialize
      super
      @active_scaffold_config = Config.new(
        ActionConfig.new(:horizontal, Columns.new([:name])),
        ActionConfig.new(nil, Columns.new([:status]))
      )
      @calls = []
      @params = {}
    end

    def active_scaffold_input_options(_column, scope, options)
      {object: :new_record, name: "record#{scope}"}.merge(options)
    end

    def batch_create_by_records
      [Record.new(7), Record.new(9)]
    end

    def active_scaffold_record_select(record, column, options, records, multiple, ui_options:)
      calls << [:record_select, record, column, options, records, multiple, ui_options]
      'record-select'
    end

    def active_scaffold_input_singular_association(column, options, select_options, ui_options:)
      calls << [:association, column, options, select_options, ui_options]
      'association'
    end

    def text_area_tag(name, value, options)
      calls << [:text_area, name, value, options]
      'text-area'
    end
  end

  def test_record_select_receives_batch_records_and_ui_options
    helper = Helper.new
    column = Column.new(:team, :record_select, {search: true}, {}, nil)

    assert_equal 'record-select', helper.active_scaffold_batch_create_by_column(column, '[0]')
    call = helper.calls.first
    assert_equal :record_select, call.first
    assert_equal [7, 9], call[4].map(&:id)
    assert call[5]
    assert_equal({search: true}, call[6])
  end

  def test_association_input_allows_multiple_batch_records
    helper = Helper.new
    column = Column.new(:team, :select, nil, {prompt: 'Team'}, Object.new)

    assert_equal 'association', helper.active_scaffold_batch_create_by_column(column)
    call = helper.calls.first
    assert_equal :association, call.first
    assert_equal [7, 9], call[2][:associated]
    assert call[2][:multiple]
    assert_equal({include_blank: false}, call[3])
    assert_equal({prompt: 'Team'}, call[4])
  end

  def test_plain_column_renders_multiline_values_and_html_options
    helper = Helper.new
    helper.params[:record] = {name: "One\nTwo"}
    column = Column.new(:name, :text, nil, {html_options: {rows: 4}}, nil)

    assert_equal 'text-area', helper.active_scaffold_batch_create_by_column(column)
    assert_equal [:text_area, :name, "One\nTwo", {object: :new_record, name: 'record', rows: 4}],
                 helper.calls.first
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

  def test_non_batch_action_has_no_fallback_columns
    helper = Helper.new
    helper.action_name = 'index'

    assert_nil helper.current_form_columns(nil, nil)
  end
end
