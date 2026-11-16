# frozen_string_literal: true

module ActiveScaffold::Actions
  module BatchUpdate
    require_relative 'batch_update/calculations'
    require_relative 'batch_update/processing'
    require_relative 'batch_update/responses'

    GENERIC_OPERATORS = %w[
      NO_UPDATE
      REPLACE
    ].freeze
    NUMERIC_OPERATORS = %w[
      PLUS
      MINUS
      TIMES
      DIVISION
    ].freeze
    NUMERIC_OPTIONS = %w[
      ABSOLUTE
      PERCENT
    ].freeze

    DATE_OPERATORS = %w[
      PLUS
      MINUS
    ].freeze

    include Calculations
    include Processing
    include Responses

    def self.included(base)
      base.send :include, ActiveScaffold::Actions::BatchBase unless base < ActiveScaffold::Actions::BatchBase
      base.before_action :batch_update_authorized_filter, only: %i[batch_edit batch_update]
      base.helper_method :batch_update_values
    end

    def batch_edit
      do_batch_edit
      respond_to_action(:batch_edit)
    end

    def batch_update
      batch_action
    end

    protected

    def batch_update_values
      @batch_update_values || {}
    end

    def do_batch_edit
      self.successful = true
      do_new
    end

    def before_do_batch_update
      @batch_update_values = update_attribute_values_from_params(
        active_scaffold_config.batch_update.columns,
        params[:record]
      )
    end

    # The default security delegates to ActiveRecordPermissions.
    # You may override the method to customize.
    def batch_update_authorized?(record = nil)
      authorized_for?(crud_type: :update)
    end

    def batch_update_ignore?(record = nil)
      false
    end

    private

    def batch_update_authorized_filter
      link = active_scaffold_config.batch_update.link || active_scaffold_config.batch_update.class.link
      raise ActiveScaffold::ActionNotAllowed unless send(link.security_method)
    end

    def batch_edit_formats
      (default_formats + active_scaffold_config.formats).uniq
    end
  end
end
