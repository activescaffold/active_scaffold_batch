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
  Association = Struct.new(:name)
  Column = Struct.new(:association)
  ActionConfig = Struct.new(:default_batch_by_column, :run_in_transaction)
  Config = Struct.new(:batch_create)

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
    attr_accessor :persisted
    attr_reader :errors

    def initialize
      @errors = Errors.new
      @persisted = false
    end

    def persisted?
      persisted
    end
  end

  class Controller
    def self.before_action(*); end

    def self.helper_method(*); end

    include ActiveScaffold::Actions::BatchCreate

    attr_accessor :record, :save_error, :successful
    attr_reader :active_scaffold_config, :params, :records, :scope

    def initialize(batch_by: nil, transaction: true)
      @params = {}
      @active_scaffold_config = Config.new(ActionConfig.new(batch_by, transaction))
      @new_records = 0
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

    public :batch_create_by_column, :batch_values_for_column, :do_batch_add, :do_batch_new,
           :run_in_transaction?, :save_batch_create_record, :validate_first?
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
end
