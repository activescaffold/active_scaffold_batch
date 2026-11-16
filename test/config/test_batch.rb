# frozen_string_literal: true

require 'test_helper'
require 'active_support/core_ext/module/attribute_accessors'

module ActiveScaffold
  module DataStructures
    class ActionLink
      attr_reader :action, :options

      def initialize(action, **options)
        @action = action
        @options = options
      end
    end
  end

  module Config
    class Base
      attr_accessor :action_group

      def self.crud_type=(_value); end

      def initialize(core)
        @core = core
      end

      def as_(key, **options)
        [key, options]
      end
    end

    class Form < Base
    end
  end
end

require_relative '../../lib/active_scaffold/config/batch_create'
require_relative '../../lib/active_scaffold/config/batch_destroy'
require_relative '../../lib/active_scaffold/config/batch_update'

class BatchConfigTest < Minitest::Test
  CreateConfig = Struct.new(:multipart?)
  Core = Struct.new(:actions, :create) do
    def label(count:)
      "#{count} records"
    end
  end

  def core
    Core.new([], CreateConfig.new(false))
  end

  def test_batch_create_defaults
    config = ActiveScaffold::Config::BatchCreate.new(core)

    assert_equal :create, config.process_mode
    assert config.list_mode_enabled
    assert config.run_in_transaction
    assert_equal :vertical, config.layout
    assert_equal 'collection', config.action_group
  end

  def test_batch_create_with_batch_column_moves_to_batch_group
    config = ActiveScaffold::Config::BatchCreate.new(core)
    config.default_batch_by_column = :team

    assert_equal 'collection.batch', config.action_group
  end

  def test_batch_update_defaults
    config = ActiveScaffold::Config::BatchUpdate.new(core)

    assert_equal :update, config.process_mode
    assert config.list_mode_enabled
    assert config.update_timestamps
    assert_equal 'collection.batch', config.action_group
  end

  def test_batch_destroy_defaults
    config = ActiveScaffold::Config::BatchDestroy.new(core)

    assert_equal :delete, config.process_mode
    assert_equal 'collection.batch.destroy', config.action_group
  end

  def test_batch_destroy_defines_listed_and_marked_links
    links = ActiveScaffold::Config::BatchDestroy.link
    scopes = links.map { |link| link.options.dig(:parameters, :batch_scope) }

    assert_equal %w[batch_destroy batch_destroy], links.map(&:action)
    assert_equal %w[LISTED MARKED], scopes
  end
end
