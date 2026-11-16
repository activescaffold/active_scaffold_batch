# frozen_string_literal: true

require 'test_helper'
require 'active_support/core_ext/object/blank'

module ActiveScaffold
  module Actions
  end
end

require_relative '../../lib/active_scaffold/actions/batch_base'

class BatchBaseTest < Minitest::Test
  DatabaseColumn = Struct.new(:type)
  Column = Struct.new(:form_ui, :column, :name)
  ActionConfig = Struct.new(:crud_type)
  Config = Struct.new(:batch_update)

  class Errors
    attr_reader :messages

    def initialize
      @messages = []
    end

    def add(attribute, message)
      messages << [attribute, message]
    end
  end

  class Record
    attr_accessor :amount
    attr_reader :errors

    def initialize(authorized: true)
      @authorized = authorized
      @errors = Errors.new
    end

    def authorized_for?(crud_type:)
      @authorized && crud_type == :update
    end
  end

  class Controller
    def self.helper_method(*); end

    include ActiveScaffold::Actions::BatchBase

    attr_accessor :action_name, :record
    attr_reader :active_scaffold_config, :params

    def initialize
      @params = {}
      @active_scaffold_config = Config.new(ActionConfig.new(:update))
      @action_name = 'batch_update'
    end

    def override_batch_update_value(form_ui)
      :numeric_value if form_ui == :numeric
    end

    def numeric_value(_column, _record, value)
      value[:value] * 2
    end

    def as_(key, **)
      key.to_s
    end

    public :authorized_for_job?, :batch_scope, :batch_successful?, :column_form_ui,
           :error_records, :set_record_attribute
  end

  def test_batch_scope_accepts_listed_and_removes_parameter
    controller = Controller.new
    controller.params[:batch_scope] = 'LISTED'

    assert_equal 'LISTED', controller.batch_scope
    refute_includes controller.params, :batch_scope
  end

  def test_batch_scope_rejects_unknown_scope
    controller = Controller.new
    controller.params[:batch_scope] = 'EVERYTHING'

    assert_nil controller.batch_scope
    refute_includes controller.params, :batch_scope
  end

  def test_batch_scope_is_memoized
    controller = Controller.new
    controller.params[:batch_scope] = 'MARKED'

    assert_equal 'MARKED', controller.batch_scope
    controller.params[:batch_scope] = 'LISTED'
    assert_equal 'MARKED', controller.batch_scope
  end

  def test_column_form_ui_falls_back_to_database_type
    controller = Controller.new
    column = Column.new(nil, DatabaseColumn.new(:integer), :amount)

    assert_equal :integer, controller.column_form_ui(column)
  end

  def test_batch_update_assigns_nested_value_without_override
    controller = Controller.new
    controller.record = Record.new
    controller.instance_variable_set(:@record, controller.record)
    column = Column.new(nil, nil, :amount)

    controller.set_record_attribute(column, :amount, {value: 12})

    assert_equal 12, controller.record.amount
  end

  def test_batch_update_uses_form_ui_override
    controller = Controller.new
    controller.record = Record.new
    controller.instance_variable_set(:@record, controller.record)
    column = Column.new(:numeric, nil, :amount)

    controller.set_record_attribute(column, :amount, {value: 12})

    assert_equal 24, controller.record.amount
  end

  def test_non_update_action_assigns_raw_value
    controller = Controller.new
    controller.action_name = 'batch_create'
    controller.record = Record.new
    controller.instance_variable_set(:@record, controller.record)
    column = Column.new(nil, nil, :amount)

    controller.set_record_attribute(column, :amount, 7)

    assert_equal 7, controller.record.amount
  end

  def test_unauthorized_record_gets_error_and_is_collected
    controller = Controller.new
    record = Record.new(authorized: false)

    refute controller.authorized_for_job?(record)
    assert_equal [[:base, 'no_authorization_for_action']], record.errors.messages
    assert_equal [record], controller.error_records
    refute controller.batch_successful?
  end

  def test_authorized_record_is_not_collected
    controller = Controller.new
    record = Record.new

    assert controller.authorized_for_job?(record)
    assert_empty controller.error_records
    assert controller.batch_successful?
  end
end
