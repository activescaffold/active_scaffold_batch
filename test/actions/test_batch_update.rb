# frozen_string_literal: true

require 'test_helper'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/integer/time'
require 'active_support/core_ext/string/inflections'

module ActiveScaffold
  module Actions
  end
end

require_relative '../../lib/active_scaffold/actions/batch_base'
require_relative '../../lib/active_scaffold/actions/batch_update'

class BatchUpdateTest < Minitest::Test
  DatabaseColumn = Struct.new(:type, :null)
  Column = Struct.new(:name, :form_ui, :column)

  class Connection
    def quote_column_name(name)
      %("#{name}")
    end
  end

  class Model
    class << self
      attr_accessor :timestamp

      def quote_value(value)
        value.nil? ? 'NULL' : value.to_s
      end

      def connection
        @connection ||= Connection.new
      end

      def touch_attributes_with_time
        {'updated_at' => timestamp}
      end
    end
  end

  BatchUpdateConfig = Struct.new(:update_timestamps)
  Config = Struct.new(:model, :batch_update)
  Record = Struct.new(:amount)
  DateRecord = Struct.new(:started_at)

  class DateValue
    def in(duration)
      [:plus, duration]
    end

    def ago(duration)
      [:minus, duration]
    end
  end

  class Columns
    def initialize(*columns)
      @columns = columns
    end

    def each_column(**, &)
      @columns.each(&)
    end
  end

  class Controller
    def self.before_action(*); end

    def self.helper_method(*); end

    def self.condition_value_for_numeric(_column, value)
      value.to_f
    end

    def self.condition_value_for_datetime(_column, value, conversion)
      [value, conversion]
    end

    include ActiveScaffold::Actions::BatchUpdate

    attr_reader :active_scaffold_config, :params
    attr_writer :batch_update_values

    def initialize
      @params = {}
      @active_scaffold_config = Config.new(Model, BatchUpdateConfig.new(true))
    end

    def action_name
      'batch_update'
    end

    def new_model
      Record.new
    end

    def column_value_from_param_value(_record, _column, value)
      "converted-#{value}"
    end

    public :batch_update_all_value_for_numeric, :batch_update_value_for_numeric,
           :batch_update_value_for_date_picker, :get_update_all_attribute,
           :update_attribute_values_from_params, :updates_for_update_all
  end

  def setup
    @controller = Controller.new
    Model.timestamp = Time.utc(2026, 11, 13, 12)
    @column = Column.new(:amount, :numeric, DatabaseColumn.new(:integer, false))
    @record = Record.new(100.0)
  end

  def numeric(operator, value: '10', opt: 'ABSOLUTE')
    @controller.batch_update_value_for_numeric(
      @column,
      @record,
      {operator: operator, value: value, opt: opt}
    )
  end

  def test_numeric_replace_and_null
    assert_equal 10.0, numeric('REPLACE')
    assert_nil numeric('NULL')
  end

  def test_numeric_arithmetic_operators
    assert_equal 110.0, numeric('PLUS')
    assert_equal 90.0, numeric('MINUS')
    assert_equal 1000.0, numeric('TIMES')
    assert_equal 10.0, numeric('DIVISION')
  end

  def test_numeric_percentage_uses_percentage_of_current_value
    assert_equal 110.0, numeric('PLUS', opt: 'PERCENT')
  end

  def test_date_picker_replaces_with_converted_value
    column = Column.new(:started_at, :date_picker, DatabaseColumn.new(:date, true))
    calculation = {operator: 'REPLACE', value: '2026-11-13'}

    value = @controller.batch_update_value_for_date_picker(column, DateRecord.new(nil), calculation)

    assert_equal ['2026-11-13', :to_date], value
  end

  def test_date_picker_shifts_current_value
    column = Column.new(:started_at, :date_picker, DatabaseColumn.new(:datetime, true))
    record = DateRecord.new(DateValue.new)

    plus = @controller.batch_update_value_for_date_picker(
      column, record, {operator: 'PLUS', value: nil, 'number' => '2', 'unit' => 'DAYS'}
    )
    minus = @controller.batch_update_value_for_date_picker(
      column, record, {operator: 'MINUS', value: nil, 'number' => '0', 'unit' => 'DAYS'}
    )

    assert_equal [:plus, 2.days], plus
    assert_equal [:minus, 1.day], minus
  end

  def test_unknown_numeric_operator_preserves_current_value
    assert_equal 100.0, numeric('UNKNOWN')
    assert_nil @controller.batch_update_all_value_for_numeric(
      @column,
      {operator: 'UNKNOWN', value: '10', opt: 'ABSOLUTE'}
    )
  end

  def test_sql_numeric_operator_quotes_column_and_operand
    sql = @controller.batch_update_all_value_for_numeric(
      @column,
      {operator: 'PLUS', value: '10', opt: 'ABSOLUTE'}
    )

    assert_equal '"amount" + 10.0', sql
  end

  def test_sql_percentage_builds_column_relative_operand
    sql = @controller.batch_update_all_value_for_numeric(
      @column,
      {operator: 'MINUS', value: '10', opt: 'PERCENT'}
    )

    assert_equal '"amount" - "amount" / 100.0 * 10.0', sql
  end

  def test_sql_null_uses_database_null
    sql = @controller.batch_update_all_value_for_numeric(
      @column,
      {operator: 'NULL', value: nil, opt: 'ABSOLUTE'}
    )

    assert_equal 'NULL', sql
  end

  def test_update_all_values_join_sql_and_bind_values
    plain_column = Column.new(:name, nil, nil)
    @controller.batch_update_values = {
      amount: {column: @column, value: {operator: 'PLUS', value: '10', opt: 'ABSOLUTE'}},
      name: {column: plain_column, value: {operator: 'REPLACE', value: 'New name'}}
    }

    assert_equal [
      'amount = "amount" + 10.0,name = ?,"updated_at" = ?',
      'New name',
      Model.timestamp
    ], @controller.updates_for_update_all
  end

  def test_update_all_can_leave_timestamps_unchanged
    @controller.active_scaffold_config.batch_update.update_timestamps = false
    plain_column = Column.new(:name, nil, nil)
    @controller.batch_update_values = {
      name: {column: plain_column, value: {operator: 'REPLACE', value: 'New name'}}
    }

    assert_equal ['name = ?', 'New name'], @controller.updates_for_update_all
  end

  def test_update_all_does_not_replace_explicit_timestamp
    timestamp_column = Column.new(:updated_at, nil, nil)
    explicit_timestamp = Time.utc(2020, 1, 1)
    @controller.batch_update_values = {
      updated_at: {column: timestamp_column, value: {operator: 'REPLACE', value: explicit_timestamp}}
    }

    assert_equal ['updated_at = ?', explicit_timestamp], @controller.updates_for_update_all
  end

  def test_attribute_params_skip_no_update_and_convert_values
    name = Column.new(:name, nil, nil)
    status = Column.new(:status, nil, nil)
    attributes = {
      name: {operator: 'REPLACE', value: 'Task'},
      status: {operator: 'NO_UPDATE', value: 'ignored'}
    }

    values = @controller.update_attribute_values_from_params(Columns.new(name, status), attributes)

    assert_equal({column: name, value: {operator: 'REPLACE', value: 'converted-Task'}}, values[:name])
    refute_includes values, :status
  end

  def test_null_operator_does_not_convert_value
    name = Column.new(:name, nil, nil)
    attributes = {name: {operator: 'NULL', value: 'ignored'}}

    values = @controller.update_attribute_values_from_params(Columns.new(name), attributes)

    assert_nil values[:name][:value][:value]
  end
end
