module ActiveScaffold::Actions
  module BatchCreate

    def self.included(base)
      base.send :include, ActiveScaffold::Actions::BatchBase unless base < ActiveScaffold::Actions::BatchBase
      base.before_action :batch_create_authorized_filter, :only => [:batch_new, :batch_create]
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
    def batch_new_respond_to_html
      if batch_successful?
        render(:action => 'batch_create')
      else
        return_to_main
      end
    end

    def batch_new_respond_to_js
      render(:partial => 'batch_create_form')
    end

    def batch_add_respond_to_js
      render
    end

    def batch_create_values
      @batch_create_values || {}
    end

    def batch_create_by_records
      if @batch_create_by_records.nil?
        if marked_records_parent
          column = active_scaffold_config.columns[batch_create_by_column.to_sym]
          @batch_create_by_records = if column.association.polymorphic?
            active_scaffold_config_for(params[:batch_create_by].singularize).model.find(marked_records_parent.keys)
          else
            column_plural_assocation_value_from_value(column, marked_records_parent.keys)
          end
        end
      end
      @batch_create_by_records || []
    end

    def batch_create_respond_to_html
      if params[:iframe]=='true' # was this an iframe post ?
        do_refresh_list
        responds_to_parent do
          render :action => 'on_batch_create.js', :layout => false
        end
      else # just a regular post
        if batch_successful?
          return_to_main
        else
          render(:action => 'batch_create')
        end
      end
    end

    def batch_create_respond_to_js
      do_refresh_list
      render :action => 'on_batch_create'
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

    def marked_records_parent
      if @marked_records_parent.nil?
        @marked_records_parent = if params[:batch_create_by]
          session_parent = active_scaffold_session_storage(params[:batch_create_by])
          session_parent['marked_records'] || {}
        else
          false
        end
      end
      @marked_records_parent
    end

    def before_do_batch_create
      if batch_create_by_column
        create_columns = active_scaffold_config.batch_create.columns
        @batch_create_values = create_attribute_values_from_params(create_columns, params[:record])
      else
        @batch_scope = 'multiple'
      end
    end

    def run_in_transaction?
      active_scaffold_config.batch_create.run_in_transaction
    end

    def validate_first?
      active_scaffold_config.batch_create.run_in_transaction == :validate_first
    end

    def run_in_transaction_if_enabled
      processed_records, created_records = 0
      if run_in_transaction?
        active_scaffold_config.model.transaction do
          processed_records, created_records = yield
          if processed_records == created_records
            @error_records.each { |key, record| create_save(record || key) } if validate_first?
            @error_records = []
          else
            created_records = 0
            raise ActiveRecord::Rollback
          end
        end
      else
        processed_records, created_records = yield
      end
      flash[:info] = as_(:some_records_created, :count => created_records, :model => active_scaffold_config.label(:count => created_records)) if batch_successful? || created_records > 0
    end

    def batch_create_listed
      run_in_transaction_if_enabled do
        processed_records = created_records = 0
        case active_scaffold_config.batch_create.process_mode
        when :create then
          batch_create_by_records.each do |batch_record|
            create_record_in_batch(batch_record)
            created_records += 1 if successful?
            processed_records += 1
          end
        else
          Rails.logger.error("Unknown process_mode: #{active_scaffold_config.batch_create.process_mode} for action batch_create")
        end
        [processed_records, created_records]
      end
    end
    alias_method :batch_create_marked, :batch_create_listed

    def batch_create_multiple
      run_in_transaction_if_enabled do
        @error_records = {}
        processed_records = created_records = 0
        params[:record].each do |scope, record_hash|
          do_create(:attributes => record_hash, :skip_save => validate_first?)
          error_records[scope] = @record unless successful? && !run_in_transaction?
          created_records += 1 if successful?
          processed_records += 1
        end
        [processed_records, created_records]
      end
    end

    def new_batch_create_record(created_by)
      new_model
    end

    def create_record_in_batch(created_by)
      @successful = nil
      @record = new_batch_create_record(created_by)
      @record.send("#{batch_create_by_column}=", created_by)
      batch_create_values.each do |attribute, value|
        set_record_attribute(value[:column], attribute, value[:value])
      end

      if authorized_for_job?(@record)
        if validate_first?
          self.successful = [@record.valid?, @record.associated_valid?].all?
        else
          create_save(@record) rescue nil
          self.successful = @record.persisted?
        end
        if successful?
          marked_records_parent.delete(created_by.id.to_s) if batch_scope == 'MARKED' && marked_records_parent
        elsif @record.errors[batch_create_by_column]
          @record.errors.messages[batch_create_by_column].map!{|e| "#{@record.send(batch_create_by_column)} #{e}"}
        end
        error_records << @record unless successful? && !run_in_transaction?
      end
    end

    def batch_create_by_column
      active_scaffold_config.batch_create.default_batch_by_column
    end

    def create_attribute_values_from_params(columns, attributes)
      values = {}
      parent_record = active_scaffold_config.model.new
      columns.each :for => active_scaffold_config.model, :crud_type => :create, :flatten => true do |column|
        next unless attributes.has_key?(column.name)
        if column == batch_create_by_column.to_sym
          @batch_create_by_records = batch_values_for_column(column, attributes[column.name])
        else
          value = column_value_from_param_value(parent_record, column, attributes[column.name])
          values[column.name] = {:column => column, :value => value}
        end
      end
      values
    end

    def batch_values_for_column(column, value)
      if column.association
        column_plural_assocation_value_from_value(column, value)
      else
        value.lines.map(&:chomp)
      end
    end

    # The default security delegates to ActiveRecordPermissions.
    # You may override the method to customize.
    def batch_create_authorized?(record = nil)
      authorized_for?(:crud_type => :create)
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
      raise ActiveScaffold::ActionNotAllowed unless self.send(link.security_method)
    end
    def batch_new_formats
      (default_formats + active_scaffold_config.formats).uniq
    end
  end
end
