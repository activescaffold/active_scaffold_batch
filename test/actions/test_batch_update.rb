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
  Link = Struct.new(:security_method)
  DatabaseColumn = Struct.new(:type, :null)
  Column = Struct.new(:name, :form_ui, :column)

  class Connection
    def quote_column_name(name)
      %("#{name}")
    end
  end

  class Model
    class << self
      attr_accessor :timestamp, :update_args, :where_args, :relation

      def quote_value(value)
        value.nil? ? 'NULL' : value.to_s
      end

      def connection
        @connection ||= Connection.new
      end

      def touch_attributes_with_time
        {'updated_at' => timestamp}
      end

      def update_all(*args)
        self.update_args = args
      end

      def primary_key
        :id
      end

      def where(args)
        self.where_args = args
        self.relation = Relation.new
      end
    end
  end

  class Relation
    attr_reader :updates

    def update_all(updates)
      @updates = updates
    end
  end

  BatchUpdateConfig = Struct.new(:update_timestamps, :process_mode, :crud_type, :columns, :link)
  Config = Struct.new(:model, :batch_update, :formats)
  class Record
    attr_accessor :amount, :as_marked

    def initialize(amount = nil)
      @amount = amount
      @as_marked = true
    end

    def authorized_for?(crud_type:)
      crud_type == :update
    end

    def to_label
      'Batch record'
    end
  end
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

    attr_accessor :successful, :update_allowed, :update_succeeds
    attr_reader :active_scaffold_config, :params, :records, :marked_records, :events,
                :flash, :rendered
    attr_writer :batch_update_values

    def initialize
      @params = {}
      @active_scaffold_config = Config.new(
        Model,
        BatchUpdateConfig.new(true, :update, :update, Columns.new, Link.new(:update_allowed?)),
        [:json]
      )
      @records = []
      @marked_records = [4, 5]
      @events = []
      @flash = {}
      @update_succeeds = true
      @update_allowed = true
    end

    def action_name
      'batch_update'
    end

    def do_new
      @record = Record.new
    end

    def respond_to_action(action)
      events << [:respond_to, action]
    end

    def process_action_link_action(action)
      events << [:action_link, action]
      yield
    end

    def authorized_for?(crud_type:)
      crud_type == :update
    end

    def update_allowed?
      update_allowed
    end

    def default_formats
      [:html]
    end

    def new_model
      Record.new
    end

    def column_value_from_param_value(_record, _column, value)
      "converted-#{value}"
    end

    def params_hash?(value)
      value.is_a?(Hash)
    end

    def each_record_in_scope(&)
      records.each(&)
    end

    def each_marked_record(&)
      records.each(&)
    end

    def update_save(**)
      self.successful = update_succeeds
    end

    def successful?
      successful != false
    end

    def all_conditions
      {active: true}
    end

    def do_search
      events << :search
    end

    def do_demark_all
      events << :demark
    end

    def do_refresh_list
      events << :refresh
    end

    def responds_to_parent
      events << :parent
      yield
    end

    def return_to_main
      events << :return
    end

    def render(**options)
      @rendered = options
    end

    def as_(key, **)
      key.to_s
    end

    public :batch_edit_respond_to_html, :batch_edit_respond_to_js,
           :batch_update_all_value_for_numeric, :batch_update_listed, :batch_update_marked,
           :batch_update_respond_to_html, :batch_update_respond_to_js,
           :batch_update_value_for_numeric, :batch_update_value_for_date_picker,
           :batch_update_authorized?, :batch_update_authorized_filter,
           :batch_update_ignore?, :before_do_batch_update,
           :error_records, :get_update_all_attribute, :override_batch_update_value,
           :update_all_listed_records, :update_all_marked_records,
           :update_attribute_values_from_params, :update_record_in_batch, :updates_for_update_all
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

  def test_sql_multiplication_and_division
    multiplication = @controller.batch_update_all_value_for_numeric(
      @column,
      {operator: 'TIMES', value: '3', opt: 'ABSOLUTE'}
    )
    division = @controller.batch_update_all_value_for_numeric(
      @column,
      {operator: 'DIVISION', value: '4', opt: 'ABSOLUTE'}
    )

    assert_equal '"amount" * 3.0', multiplication
    assert_equal '"amount" / 4.0', division
  end

  def test_form_ui_override_is_used_only_when_a_handler_exists
    assert_equal 'batch_update_value_for_numeric', @controller.override_batch_update_value(:numeric)
    assert_nil @controller.override_batch_update_value(:unknown)
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

  def test_listed_update_assigns_values_and_saves_each_record
    name = Column.new(:amount, nil, nil)
    @controller.batch_update_values = {
      amount: {column: name, value: {operator: 'REPLACE', value: 42}}
    }
    record = Record.new(10)
    @controller.records << record

    @controller.batch_update_listed

    assert_equal 42, record.amount
    assert_empty @controller.error_records
  end

  def test_marked_update_unmarks_successful_records
    @controller.params[:batch_scope] = 'MARKED'
    @controller.records << @record

    @controller.batch_update_marked

    assert_equal false, @record.as_marked
  end

  def test_failed_update_collects_the_record
    @controller.update_succeeds = false
    @controller.records << @record

    @controller.batch_update_listed

    assert_equal [@record], @controller.error_records
  end

  def test_listed_update_all_runs_search_and_updates_model
    @controller.active_scaffold_config.batch_update.process_mode = :update_all
    @controller.batch_update_values = {
      amount: {column: @column, value: {operator: 'REPLACE', value: '12', opt: 'ABSOLUTE'}}
    }

    @controller.batch_update_listed

    assert_includes @controller.events, :search
    assert_equal({active: true}, Model.update_args.last)
  end

  def test_marked_update_all_targets_ids_and_clears_marks
    @controller.active_scaffold_config.batch_update.process_mode = :update_all
    @controller.batch_update_values = {
      amount: {column: @column, value: {operator: 'REPLACE', value: '12', opt: 'ABSOLUTE'}}
    }

    @controller.batch_update_marked

    assert_equal({id: [4, 5]}, Model.where_args)
    assert Model.relation.updates
    assert_includes @controller.events, :demark
  end

  def test_edit_responses_render_form_or_return_to_main
    @controller.batch_edit_respond_to_html
    assert_equal({action: 'batch_update'}, @controller.rendered)
    @controller.batch_edit_respond_to_js
    assert_equal({partial: 'batch_update_form'}, @controller.rendered)

    @controller.error_records << @record
    @controller.batch_edit_respond_to_html
    assert_includes @controller.events, :return
  end

  def test_public_edit_and_update_actions_initialize_and_process_values
    @controller.batch_edit
    @controller.params[:record] = {}
    @controller.params[:batch_scope] = 'LISTED'
    @controller.batch_update

    assert_includes @controller.events, %i[respond_to batch_edit]
    assert_includes @controller.events, %i[action_link batch_base]
    assert_instance_of Record, @controller.instance_variable_get(:@record)
  end

  def test_default_authorization_ignore_and_edit_formats
    assert @controller.batch_update_authorized?
    refute @controller.batch_update_ignore?
    assert_equal %i[html json], @controller.send(:batch_edit_formats)
  end

  def test_batch_update_configuration_authorization
    @controller.batch_update_authorized_filter
    @controller.update_allowed = false

    assert_raises(ActiveScaffold::ActionNotAllowed) { @controller.batch_update_authorized_filter }
  end

  def test_update_html_response_handles_success_error_and_iframe
    @controller.instance_variable_set(:@record, @record)
    @controller.batch_update_respond_to_html
    assert_equal 'updated_model', @controller.flash[:info]
    assert_includes @controller.events, :return

    @controller.error_records << @record
    @controller.batch_update_respond_to_html
    assert_equal({action: 'batch_update'}, @controller.rendered)

    @controller.params[:iframe] = 'true'
    @controller.error_records.clear
    @controller.successful = true
    @controller.batch_update_respond_to_html
    assert_includes @controller.events, :refresh
    assert_equal({action: 'on_batch_update.js', layout: false}, @controller.rendered)
  end

  def test_update_js_response_refreshes_and_renders
    @controller.batch_update_respond_to_js

    assert_equal 'batch_processing_successful', @controller.flash[:info]
    assert_includes @controller.events, :refresh
    assert_equal({action: 'on_batch_update'}, @controller.rendered)
  end
end
