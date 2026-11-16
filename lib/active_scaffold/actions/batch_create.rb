# frozen_string_literal: true

module ActiveScaffold::Actions
  module BatchCreate
    require_relative 'batch_create/processing'
    require_relative 'batch_create/records'
    require_relative 'batch_create/responses'

    include Processing
    include Records
    include Responses

    def self.included(base)
      base.send :include, ActiveScaffold::Actions::BatchBase unless base < ActiveScaffold::Actions::BatchBase
      base.before_action :batch_create_authorized_filter, only: %i[batch_new batch_create]
      base.helper_method :batch_create_values
      base.helper_method :batch_create_by_column
      base.helper_method :batch_create_by_records
    end

    def batch_new
      do_batch_new
      respond_to_action(:batch_new)
    end

    def batch_add
      do_batch_add
      respond_to_action(:batch_add)
    end

    def batch_create
      batch_action
    end

    protected

    def batch_create_values
      @batch_create_values || {}
    end

    def do_batch_new
      self.successful = true
      do_new
      if batch_create_by_column
        batch_scope # that s a dummy call to remove batch_scope parameter
      else
        @scope = temporary_id
      end
    end

    def do_batch_add
      @records = {}
      t = temporary_id
      params[:num_records].to_i.times do
        @records[t.succ!] = do_new
      end
    end

    def batch_create_by_column
      active_scaffold_config.batch_create.default_batch_by_column
    end

    # The default security delegates to ActiveRecordPermissions.
    # You may override the method to customize.
    def batch_create_authorized?(record = nil)
      authorized_for?(crud_type: :create)
    end

    def batch_create_ignore?(record = nil)
      false
    end

    def override_batch_create_value(form_ui)
      method = "batch_create_value_for_#{form_ui}"
      method if respond_to? method, true
    end

    def create_ignore?
      super || batch_create_by_column.blank?
    end

    private

    def batch_create_authorized_filter
      link = active_scaffold_config.batch_create.link || active_scaffold_config.batch_create.class.link
      raise ActiveScaffold::ActionNotAllowed unless send(link.security_method)
    end

    def batch_new_formats
      (default_formats + active_scaffold_config.formats).uniq
    end
  end
end
