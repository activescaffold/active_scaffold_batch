# frozen_string_literal: true

require 'test_helper'

module ActiveScaffold
  module Actions
  end

  module Helpers
  end
end

require_relative '../../lib/active_scaffold/actions/batch_update'
require_relative '../../lib/active_scaffold/helpers/update_column_helpers'

class UpdateColumnHelpersTest < Minitest::Test
  DatabaseColumn = Struct.new(:null, :type)
  Column = Struct.new(:name, :column, :form_ui)
  BatchUpdateConfig = Struct.new(:list_mode_enabled)
  Config = Struct.new(:batch_update, :actions)

  class Helper
    include ActiveScaffold::Helpers::UpdateColumnHelpers

    attr_accessor :batch_values, :update_override
    attr_reader :active_scaffold_config, :attribute_calls

    def initialize(listed: true, marked: true)
      actions = marked ? [:mark] : []
      @active_scaffold_config = Config.new(BatchUpdateConfig.new(listed), actions)
      @attribute_calls = []
      @batch_values = {}
    end

    def as_(key)
      "label-#{key}"
    end

    def as_element_attributes(key, **options)
      @attribute_calls << [key, options]
      options
    end

    def batch_scope
      nil
    end

    def hidden_field_tag(name, value)
      "hidden:#{name}:#{value}"
    end

    def select_tag(name, options, attributes)
      "select:#{name}:#{options}:#{attributes[:class]}"
    end

    def options_for_select(options, selected)
      "#{options.inspect}:#{selected}"
    end

    def active_scaffold_input_options(_column, _scope, options)
      {object: :record, id: 'record_name', required: true}.merge(options)
    end

    def override_helper(*)
      update_override
    end

    def custom_update_field(record, options)
      "custom:#{record}:#{options[:id]}"
    end

    def active_scaffold_render_input(column, options)
      "input:#{column.name}:#{options[:name]}:#{options[:style]}"
    end

    def safe_join(parts, separator)
      parts.join(separator)
    end

    def text_field_tag(name, value, attributes)
      "text:#{name}:#{value}:#{attributes[:id]}:#{attributes[:style]}"
    end

    def active_scaffold_input_text_options(attributes)
      attributes
    end

    def batch_update_values
      batch_values
    end
  end

  def test_generic_operators_include_null_for_nullable_column
    helper = Helper.new
    column = Column.new(:name, DatabaseColumn.new(true, :string), nil)

    assert_includes helper.active_scaffold_update_generic_operators(column), %w[label-null NULL]
  end

  def test_generic_operators_omit_null_for_required_column
    helper = Helper.new
    column = Column.new(:name, DatabaseColumn.new(false, :string), nil)

    refute_includes helper.active_scaffold_update_generic_operators(column), %w[label-null NULL]
  end

  def test_scope_options_include_enabled_list_and_marked_modes
    helper = Helper.new

    assert_equal(
      [%w[label-listed LISTED], %w[label-marked MARKED]],
      helper.active_scaffold_update_scope_select_options
    )
  end

  def test_scope_options_respect_disabled_modes
    helper = Helper.new(listed: false, marked: false)

    assert_empty helper.active_scaffold_update_scope_select_options
  end

  def test_single_scope_renders_hidden_field
    helper = Helper.new(marked: false)

    assert_equal 'hidden:batch_scope:LISTED', helper.active_scaffold_update_scope_select
  end

  def test_multiple_scopes_render_select_and_ui_attributes
    helper = Helper.new

    result = helper.active_scaffold_update_scope_select

    assert_match(/^select:batch_scope:/, result)
    assert_includes helper.attribute_calls, [
      :form_control,
      {proc_options: {column: nil, form_ui: :select, batch_role: :batch_scope}, class: 'text-input'}
    ]
  end

  def test_update_field_override_takes_precedence
    helper = Helper.new
    helper.update_override = :custom_update_field
    column = Column.new(:name, nil, nil)

    assert_equal 'custom:record:record_name', helper.active_scaffold_update_for(column)
  end

  def test_generic_update_renders_operator_and_hidden_value_input
    helper = Helper.new
    column = Column.new(:name, nil, nil)

    html = helper.active_scaffold_update_for(column)

    assert_includes html, 'select:record[name][operator]'
    assert_includes html, 'input:name:record[name][value]:display: none;'
  end

  def test_generic_update_shows_value_for_replace_operator
    helper = Helper.new
    helper.batch_values = {name: {value: {operator: 'REPLACE'}}}
    column = Column.new(:name, nil, nil)

    html = helper.active_scaffold_update_for(column)

    assert_includes html, 'input:name:record[name][value]:'
    refute_includes html, 'display: none;'
  end

  def test_numeric_update_renders_operator_value_and_option_controls
    helper = Helper.new
    helper.batch_values = {
      amount: {value: {'operator' => 'PLUS', 'value' => '5', 'opt' => 'PERCENT'}}
    }
    column = Column.new(:amount, DatabaseColumn.new(false, :integer), :numeric)

    html = helper.active_scaffold_update_numeric(column, id: 'record_amount')

    assert_includes html, 'record[amount][operator]'
    assert_includes html, 'text:record[amount][value]:5:record_amount_value:'
    assert_includes html, 'record[amount][opt]'
    assert helper.attribute_calls.any? { |_, options| options[:proc_options][:batch_role] == :batch_update_value }
  end

  def test_form_ui_dispatches_to_numeric_update
    helper = Helper.new
    column = Column.new(:amount, DatabaseColumn.new(false, :integer), :numeric)

    html = helper.active_scaffold_update_for(column)

    assert_includes html, 'record[amount][operator]'
  end
end
