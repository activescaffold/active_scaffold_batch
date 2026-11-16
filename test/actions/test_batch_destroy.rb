# frozen_string_literal: true

require 'test_helper'
require 'active_support/core_ext/enumerable'

module ActiveScaffold
  module Actions
  end
end

require_relative '../../lib/active_scaffold/actions/batch_base'
require_relative '../../lib/active_scaffold/actions/batch_destroy'

class BatchDestroyTest < Minitest::Test
  Link = Struct.new(:security_method)
  ActionConfig = Struct.new(:process_mode, :link)
  Config = Struct.new(:batch_destroy, :actions, :model)

  class Errors
    def add(*); end
  end

  class Record
    attr_accessor :as_marked
    attr_reader :errors

    def initialize(successful: true)
      @successful = successful
      @as_marked = true
      @errors = Errors.new
    end

    def successful?
      @successful
    end

    def authorized_for?(**)
      true
    end
  end

  class Relation
    attr_reader :delete_args, :where_args

    def where(*args)
      @where_args = args
      self
    end

    def delete_all(*args)
      @delete_args = args
      nil
    end

    def deleted? = !delete_args.nil?
  end

  class Model
    class << self
      attr_reader :where_args, :relation

      def primary_key
        :id
      end

      def where(args)
        @where_args = args
        @relation = Relation.new
      end
    end
  end

  class Controller
    def self.before_action(*); end

    def self.helper_method(*); end

    include ActiveScaffold::Actions::BatchDestroy

    attr_accessor :destroy_allowed
    attr_reader :active_scaffold_config, :demarked, :marked_records, :params, :processed_actions, :records

    def initialize(process_mode: :delete)
      @params = {}
      @active_scaffold_config = Config.new(
        ActionConfig.new(process_mode, [Link.new(:destroy_allowed?)]),
        [:mark],
        Model
      )
      @marked_records = [1, 2]
      @records = []
      @processed_actions = []
      @destroy_allowed = true
    end

    def action_name
      'batch_destroy'
    end

    def do_destroy(record)
      @successful = record.successful?
    end

    def successful?
      @successful
    end

    def do_demark_all
      @demarked = true
    end

    def each_record_in_scope(&)
      records.each(&)
    end

    def each_marked_record(&)
      records.each(&)
    end

    def filtered_query
      @filtered_query ||= Relation.new
    end

    def all_conditions
      {active: true}
    end

    def authorized_for?(crud_type:)
      crud_type == :delete
    end

    def destroy_allowed?
      destroy_allowed
    end

    def process_action_link_action(action)
      processed_actions << action
      yield
    end

    def authorized_for_job?(_record)
      true
    end

    public :batch_destroy_authorized?, :batch_destroy_authorized_filter,
           :batch_destroy_listed, :batch_destroy_marked,
           :batch_destroy_marked_ignore?, :destroy_record, :error_records
  end

  def test_successful_marked_destroy_unmarks_record
    controller = Controller.new
    controller.params[:batch_scope] = 'MARKED'
    record = Record.new

    controller.destroy_record(record)

    assert_equal false, record.as_marked
    assert_empty controller.error_records
  end

  def test_failed_destroy_collects_record
    controller = Controller.new
    record = Record.new(successful: false)

    controller.destroy_record(record)

    assert_equal [record], controller.error_records
  end

  def test_delete_all_removes_marked_ids_and_clears_marks
    controller = Controller.new(process_mode: :delete_all)

    controller.batch_destroy_marked

    assert_equal({id: [1, 2]}, Model.where_args)
    assert Model.relation.deleted?
    assert controller.demarked
  end

  def test_delete_all_removes_every_record_in_the_filtered_list
    controller = Controller.new(process_mode: :delete_all)

    controller.batch_destroy_listed

    assert_equal ['1=1'], controller.filtered_query.where_args
    assert_equal [{active: true}], controller.filtered_query.delete_args
  end

  def test_marked_link_is_ignored_without_mark_action
    controller = Controller.new
    controller.active_scaffold_config.actions.clear

    assert controller.batch_destroy_marked_ignore?
  end

  def test_listed_destroy_processes_each_record
    controller = Controller.new
    record = Record.new
    controller.records << record

    controller.batch_destroy_listed

    assert record.as_marked
    assert_empty controller.error_records
  end

  def test_marked_destroy_processes_each_record
    controller = Controller.new
    record = Record.new
    controller.records << record

    controller.batch_destroy_marked

    assert_empty controller.error_records
  end

  def test_public_action_and_default_authorization
    controller = Controller.new

    controller.batch_destroy

    assert_equal [:batch_base], controller.processed_actions
    assert controller.batch_destroy_authorized?
  end

  def test_batch_destroy_configuration_authorization
    controller = Controller.new

    controller.batch_destroy_authorized_filter
    controller.destroy_allowed = false

    assert_raises(ActiveScaffold::ActionNotAllowed) { controller.batch_destroy_authorized_filter }
  end
end
