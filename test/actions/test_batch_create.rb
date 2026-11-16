# frozen_string_literal: true

require 'test_helper'
require 'active_record'
require 'active_support/core_ext/object/blank'

module ActiveScaffold
  module Actions
  end
end

require_relative '../../lib/active_scaffold/actions/batch_base'
require_relative '../../lib/active_scaffold/actions/batch_create'

class BatchCreateTest < Minitest::Test
  Link = Struct.new(:security_method)
  Association = Struct.new(:name, :polymorphic) do
    alias_method :polymorphic?, :polymorphic
  end
  Column = Struct.new(:association, :name, :form_ui, :column) do
    def ==(other)
      other == name || super
    end
  end
  ActionConfig = Struct.new(
    :default_batch_by_column,
    :run_in_transaction,
    :process_mode,
    :columns,
    :crud_type,
    :link
  )

  class Config
    attr_accessor :batch_create, :model, :columns, :formats

    def initialize(batch_create, model = Model, columns = {})
      @batch_create = batch_create
      @model = model
      @columns = columns
      @formats = [:json]
    end

    def label(count:)
      "#{count} records"
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

  class Model
    class << self
      attr_accessor :rolled_back

      def transaction
        yield
      rescue ActiveRecord::Rollback
        self.rolled_back = true
      end

      def new # rubocop:disable Rails/Delegate -- preserve lexical constant lookup in this test double
        Record.new
      end
    end
  end

  class Errors
    attr_reader :messages

    delegate :[], :delete, to: :messages

    def initialize
      @messages = Hash.new { |hash, key| hash[key] = [] }
    end

    def add(attribute, message)
      messages[attribute] << message
    end

    def empty?
      messages.values.all?(&:empty?)
    end
  end

  class Record
    attr_accessor :persisted, :team, :name, :valid_result, :associated_valid_result
    attr_reader :errors

    def initialize
      @errors = Errors.new
      @persisted = false
      @valid_result = true
      @associated_valid_result = true
    end

    def persisted?
      persisted
    end

    def valid?
      valid_result
    end

    def associated_valid?
      associated_valid_result
    end

    def authorized_for?(crud_type:)
      crud_type == :create
    end
  end

  class ParentController
    def create_ignore?
      false
    end
  end

  class Controller < ParentController
    def self.before_action(*); end

    def self.helper_method(*); end

    include ActiveScaffold::Actions::BatchCreate

    attr_accessor :create_allowed, :record, :save_error, :successful
    attr_reader :active_scaffold_config, :params, :records, :scope, :flash, :events, :rendered

    def initialize(batch_by: nil, transaction: true)
      super()
      @params = {}
      config = ActionConfig.new(batch_by, transaction, :create, Columns.new, :create, Link.new(:create_allowed?))
      @active_scaffold_config = Config.new(config)
      @new_records = 0
      @flash = {}
      @events = []
      @create_allowed = true
    end

    def do_new
      @new_records += 1
      Object.new
    end

    def temporary_id
      +'1000'
    end

    def column_plural_assocation_value_from_value(_column, value)
      value.map { |id| "record-#{id}" }
    end

    def create_save(record)
      record.persisted = true
      raise save_error if save_error
    end

    def successful?
      successful.nil? || successful
    end

    def action_name
      'batch_create'
    end

    def new_model
      Record.new
    end

    def authorized_for?(crud_type:)
      crud_type == :create
    end

    def create_allowed?
      create_allowed
    end

    def default_formats
      [:html]
    end

    def column_value_from_param_value(_record, _column, value)
      "converted-#{value}"
    end

    def params_hash?(value)
      value.is_a?(Hash)
    end

    def render(**options)
      @rendered = options
    end

    def respond_to_action(action)
      events << [:respond_to, action]
    end

    def process_action_link_action(action)
      events << [:action_link, action]
      yield
    end

    def active_scaffold_session_storage(id)
      @session_storage ||= {}
      @session_storage[id] ||= {}
    end

    def return_to_main
      events << :return
    end

    def do_refresh_list
      events << :refresh
    end

    def responds_to_parent
      events << :parent
      yield
    end

    def as_(key, **options)
      [key, options]
    end

    def do_create(attributes:, skip_save:)
      @record = Record.new
      @record.name = attributes[:name]
      @record.persisted = !skip_save
      self.successful = attributes[:valid] != false
    end

    public :batch_add_respond_to_js, :batch_create_by_column, :batch_create_listed,
           :batch_create_multiple, :batch_create_respond_to_html, :batch_create_respond_to_js,
           :batch_new_respond_to_html, :batch_new_respond_to_js, :batch_values_for_column,
           :before_do_batch_create, :create_attribute_values_from_params,
           :batch_create_authorized_filter,
           :create_record_in_batch, :do_batch_add, :do_batch_new, :error_records,
           :load_marked_records_parent, :marked_records_parent, :normalize_batch_create_errors,
           :records_for_batch_create_column, :run_in_transaction?, :run_in_transaction_if_enabled,
           :save_batch_create_record, :validate_first?
  end

  def test_scalar_batch_values_are_split_by_line
    controller = Controller.new

    assert_equal %w[one two], controller.batch_values_for_column(Column.new(nil), "one\ntwo\n")
  end

  def test_association_batch_values_use_association_conversion
    controller = Controller.new

    assert_equal %w[record-1 record-2], controller.batch_values_for_column(Column.new(Association.new(:teams)), %w[1 2])
  end

  def test_batch_new_without_batch_column_uses_temporary_scope
    controller = Controller.new

    controller.do_batch_new

    assert controller.successful
    assert_equal '1000', controller.scope
  end

  def test_batch_new_with_batch_column_consumes_the_requested_scope
    controller = Controller.new(batch_by: :team)
    controller.params[:batch_scope] = 'MARKED'

    controller.do_batch_new

    refute_includes controller.params, :batch_scope
    assert_equal 'MARKED', controller.send(:batch_scope)
  end

  def test_batch_add_builds_requested_number_of_records
    controller = Controller.new
    controller.params[:num_records] = '3'

    controller.do_batch_add

    assert_equal 3, controller.records.length
    assert_equal %w[1001 1002 1003], controller.records.keys
  end

  def test_transaction_modes
    assert Controller.new(transaction: true).run_in_transaction?
    assert Controller.new(transaction: :validate_first).validate_first?
    refute Controller.new(transaction: false).run_in_transaction?
  end

  def test_batch_create_by_column_comes_from_configuration
    controller = Controller.new(batch_by: :team)

    assert_equal :team, controller.batch_create_by_column
  end

  def test_public_batch_create_processes_the_action_link
    controller = Controller.new
    controller.params[:record] = {}

    controller.batch_create

    assert_includes controller.events, %i[action_link batch_base]
  end

  def test_marked_records_are_loaded_from_the_parent_session
    controller = Controller.new(batch_by: :team)
    controller.params[:batch_create_by] = 'projects'
    controller.active_scaffold_session_storage('projects')['marked_records'] = {'1' => true, '2' => true}

    assert_equal({'1' => true, '2' => true}, controller.marked_records_parent)
  end

  def test_batch_records_are_lazily_loaded_from_the_configured_column
    controller = Controller.new(batch_by: :team)
    controller.active_scaffold_config.columns[:team] = Column.new(Association.new(:teams, false), :team)
    controller.params[:batch_create_by] = 'projects'
    controller.active_scaffold_session_storage('projects')['marked_records'] = {'1' => true, '2' => true}

    assert_equal %w[record-1 record-2], controller.send(:batch_create_by_records)
  end

  def test_records_for_batch_column_support_regular_and_polymorphic_associations
    controller = Controller.new(batch_by: :team)
    controller.params[:batch_create_by] = 'projects'
    controller.active_scaffold_session_storage('projects')['marked_records'] = {'1' => true, '2' => true}

    regular_column = Column.new(Association.new(:teams, false), :team)
    regular = controller.records_for_batch_create_column(regular_column)
    found_ids = nil
    polymorphic_model = Object.new
    polymorphic_model.define_singleton_method(:find) { |ids| found_ids = ids }
    polymorphic_config = Struct.new(:model).new(polymorphic_model)
    controller.define_singleton_method(:active_scaffold_config_for) { |_name| polymorphic_config }
    polymorphic_column = Column.new(Association.new(:teams, true), :team)
    polymorphic = controller.records_for_batch_create_column(polymorphic_column)

    assert_equal %w[record-1 record-2], regular
    assert_equal %w[1 2], found_ids
    assert_equal %w[1 2], polymorphic
  end

  def test_submitted_batch_column_selects_records_instead_of_becoming_a_common_value
    controller = Controller.new(batch_by: :team)
    team = Column.new(nil, :team)

    values = controller.create_attribute_values_from_params(Columns.new(team), team: "one\ntwo")

    assert_empty values
    assert_equal %w[one two], controller.send(:batch_create_by_records)
  end

  def test_association_save_error_marks_persisted_record_unsuccessful
    controller = Controller.new
    record = Record.new
    controller.record = record
    controller.save_error = ActiveRecord::RecordNotSaved.new('association failed')

    controller.save_batch_create_record

    assert record.persisted?
    refute controller.successful
    assert_equal ['association failed'], record.errors[:base]
  end

  def test_before_create_extracts_values_for_batch_column_mode
    controller = Controller.new(batch_by: :team)
    name = Column.new(nil, :name)
    controller.active_scaffold_config.batch_create.columns = Columns.new(name)
    controller.params[:record] = {name: 'Task'}

    controller.before_do_batch_create

    values = controller.send(:batch_create_values)
    assert_equal 'converted-Task', values[:name][:value]
  end

  def test_before_create_uses_multiple_scope_without_batch_column
    controller = Controller.new

    controller.before_do_batch_create

    assert_equal 'multiple', controller.instance_variable_get(:@batch_scope)
  end

  def test_listed_create_builds_and_saves_each_batch_record
    controller = Controller.new(batch_by: :team, transaction: false)
    first = Struct.new(:id).new(1)
    second = Struct.new(:id).new(2)
    controller.instance_variable_set(:@batch_create_by_records, [first, second])

    controller.batch_create_listed

    assert_equal [:some_records_created, {count: 2, model: '2 records'}], controller.flash[:info]
    assert_empty controller.error_records
  end

  def test_listed_create_applies_common_values_to_each_record
    controller = Controller.new(batch_by: :team, transaction: false)
    created_by = Struct.new(:id).new(1)
    name = Column.new(nil, :name)
    controller.instance_variable_set(:@batch_create_values, name: {column: name, value: 'Shared'})

    controller.create_record_in_batch(created_by)

    assert_equal 'Shared', controller.record.name
  end

  def test_multiple_create_collects_invalid_records
    controller = Controller.new(transaction: false)
    controller.params[:record] = {
      '1' => {name: 'Good'},
      '2' => {name: 'Bad', valid: false}
    }

    controller.batch_create_multiple

    assert_equal ['2'], controller.error_records.keys
    assert_equal 'Bad', controller.error_records['2'].name
  end

  def test_validate_first_checks_record_and_associations
    controller = Controller.new(batch_by: :team, transaction: :validate_first)
    record = Record.new
    record.associated_valid_result = false
    controller.define_singleton_method(:new_batch_create_record) { |_created_by| record }
    controller.instance_variable_set(:@batch_create_values, {})

    controller.create_record_in_batch(Struct.new(:id).new(1))

    refute controller.successful
    assert_includes controller.error_records, record
  end

  def test_validate_first_saves_all_records_after_successful_validation
    controller = Controller.new(transaction: :validate_first)
    controller.params[:record] = {
      '1' => {name: 'First'},
      '2' => {name: 'Second'}
    }

    controller.batch_create_multiple

    assert_empty controller.error_records
    assert_equal [:some_records_created, {count: 2, model: '2 records'}], controller.flash[:info]
  end

  def test_transaction_rolls_back_when_any_record_is_invalid
    Model.rolled_back = false
    controller = Controller.new(transaction: true)
    controller.params[:record] = {
      '1' => {name: 'Good'},
      '2' => {name: 'Bad', valid: false}
    }

    controller.batch_create_multiple

    assert Model.rolled_back
    assert_equal %w[1 2], controller.error_records.keys
    refute_includes controller.flash, :info
  end

  def test_batch_column_validation_errors_include_the_attempted_value
    controller = Controller.new(batch_by: :team)
    record = Record.new
    record.team = 'Blue'
    record.errors.add(:team, 'is invalid')
    controller.record = record

    controller.normalize_batch_create_errors

    assert_equal ['Blue is invalid'], record.errors[:team]
  end

  def test_new_and_create_responses_cover_success_error_and_iframe
    controller = Controller.new
    controller.batch_new_respond_to_html
    assert_equal({action: 'batch_create'}, controller.rendered)
    controller.error_records << Record.new
    controller.batch_new_respond_to_html
    assert_includes controller.events, :return
    controller.error_records.clear
    controller.batch_new_respond_to_js
    assert_equal({partial: 'batch_create_form'}, controller.rendered)
    controller.batch_add_respond_to_js
    assert_equal({}, controller.rendered)

    controller.error_records << Record.new
    controller.batch_create_respond_to_html
    assert_equal({action: 'batch_create'}, controller.rendered)
    controller.error_records.clear
    controller.batch_create_respond_to_html
    assert_includes controller.events, :return

    controller.params[:iframe] = 'true'
    controller.batch_create_respond_to_html
    assert_includes controller.events, :refresh
    assert_equal({action: 'on_batch_create.js', layout: false}, controller.rendered)
  end

  def test_create_js_response_refreshes_and_renders
    controller = Controller.new

    controller.batch_create_respond_to_js

    assert_equal [:refresh], controller.events
    assert_equal({action: 'on_batch_create'}, controller.rendered)
  end

  def test_public_new_and_add_actions_process_and_respond
    controller = Controller.new
    controller.params[:num_records] = '2'

    controller.batch_new
    controller.batch_add

    assert_includes controller.events, %i[respond_to batch_new]
    assert_includes controller.events, %i[respond_to batch_add]
    assert_equal 2, controller.records.size
  end

  def test_authorization_ignore_and_value_override_defaults
    controller = Controller.new

    assert controller.send(:batch_create_authorized?)
    refute controller.send(:batch_create_ignore?)
    assert_nil controller.send(:override_batch_create_value, :unknown)
  end

  def test_batch_create_configuration_authorization_ignore_and_formats
    controller = Controller.new(batch_by: :team)

    controller.batch_create_authorized_filter
    refute controller.send(:create_ignore?)
    assert_equal %i[html json], controller.send(:batch_new_formats)

    controller.create_allowed = false
    assert_raises(ActiveScaffold::ActionNotAllowed) { controller.batch_create_authorized_filter }

    assert Controller.new.send(:create_ignore?)
  end
end
