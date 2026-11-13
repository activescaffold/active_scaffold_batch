# frozen_string_literal: true

require 'minitest/autorun'

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

    attr_reader :active_scaffold_config, :attribute_calls

    def initialize(listed: true, marked: true)
      actions = marked ? [:mark] : []
      @active_scaffold_config = Config.new(BatchUpdateConfig.new(listed), actions)
      @attribute_calls = []
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
end
