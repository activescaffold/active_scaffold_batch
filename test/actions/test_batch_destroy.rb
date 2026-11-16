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
  ActionConfig = Struct.new(:process_mode)
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
    attr_reader :deleted

    def delete_all
      @deleted = true
    end
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

    attr_reader :active_scaffold_config, :demarked, :marked_records, :params

    def initialize(process_mode: :delete)
      @params = {}
      @active_scaffold_config = Config.new(ActionConfig.new(process_mode), [:mark], Model)
      @marked_records = [1, 2]
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

    public :batch_destroy_marked, :batch_destroy_marked_ignore?, :destroy_record, :error_records
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
    assert Model.relation.deleted
    assert controller.demarked
  end

  def test_marked_link_is_ignored_without_mark_action
    controller = Controller.new
    controller.active_scaffold_config.actions.clear

    assert controller.batch_destroy_marked_ignore?
  end
end
