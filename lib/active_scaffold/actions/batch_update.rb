# frozen_string_literal: true

module ActiveScaffold::Actions
  module BatchUpdate
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

    def batch_edit_respond_to_html
      if batch_successful?
        render(action: 'batch_update')
      else
        return_to_main
      end
    end

    def batch_edit_respond_to_js
      render(partial: 'batch_update_form')
    end

    def batch_update_values
      @batch_update_values || {}
    end

    def batch_update_respond_to_html
      if params[:iframe] == 'true' # was this an iframe post ?
        flash[:info] = as_(:batch_processing_successful) if batch_successful?
        do_refresh_list
        responds_to_parent do
          render action: 'on_batch_update.js', layout: false
        end
      else # just a regular post
        if batch_successful?
          flash[:info] = as_(:updated_model, model: @record.to_label)
          return_to_main
        else
          render(action: 'batch_update')
        end
      end
    end

    def batch_update_respond_to_js
      flash[:info] = as_(:batch_processing_successful) if batch_successful?
      do_refresh_list
      render action: 'on_batch_update'
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

    def batch_update_listed
      case active_scaffold_config.batch_update.process_mode
      when :update
        each_record_in_scope { |record| update_record_in_batch(record) if authorized_for_job?(record) }
      when :update_all
        updates = updates_for_update_all
        unless updates.first.empty?
          do_search if respond_to? :do_search, true
          # all_conditions might fail cause joins are not working in update_all
          # update_all is the explicitly configured batch processing mode.
          active_scaffold_config.model.update_all(updates, all_conditions) # rubocop:disable Rails/SkipsModelValidations
        end
      else
        Rails.logger.error "Unknown process_mode: #{active_scaffold_config.batch_update.process_mode} " \
                           'for action batch_update'
      end
    end

    def batch_update_marked
      case active_scaffold_config.batch_update.process_mode
      when :update
        each_marked_record { |record| update_record_in_batch(record) if authorized_for_job?(record) }
      when :update_all
        updates = updates_for_update_all
        unless updates.first.empty?
          model = active_scaffold_config.model
          # update_all is the explicitly configured batch processing mode.
          model.where(model.primary_key => marked_records.to_a).update_all(updates) # rubocop:disable Rails/SkipsModelValidations
          do_demark_all
        end
      else
        Rails.logger.error "Unknown process_mode: #{active_scaffold_config.batch_update.process_mode} " \
                           'for action batch_update'
      end
    end

    def updates_for_update_all
      update_all = [[]]
      batch_update_values.each do |attribute, value|
        sql_set, value = get_update_all_attribute(value[:column], attribute, value[:value])
        unless sql_set.nil?
          update_all.first << sql_set
          update_all << value if value.present?
        end
      end
      add_timestamps_to_update_all(update_all) if update_all.first.any?
      update_all[0] = update_all.first.join(',')
      update_all
    end

    def add_timestamps_to_update_all(update_all)
      return unless active_scaffold_config.batch_update.update_timestamps

      model = active_scaffold_config.model
      model.touch_attributes_with_time.each do |attribute, time|
        next if batch_update_values.key?(attribute) || batch_update_values.key?(attribute.to_sym)

        quoted_attribute = model.connection.quote_column_name(attribute)
        update_all.first << "#{quoted_attribute} = ?"
        update_all << time
      end
    end

    def update_record_in_batch(record)
      @successful = nil
      @record = record

      batch_update_values.each do |attribute, value|
        set_record_attribute(value[:column], attribute, value[:value])
      end

      update_save(no_record_param_update: true)
      if successful?
        @record.as_marked = false if batch_scope == 'MARKED'
      else
        error_records << @record
      end
    end

    def get_update_all_attribute(column, attribute, value)
      form_ui = column_form_ui(column)

      if form_ui && (method = override_batch_update_all_value(form_ui))
        update_value = send(method, column, value)
        if update_value.nil?
          sql_set = nil
        else
          sql_set = "#{attribute} = #{update_value}"
          update_value = nil
        end
      else
        sql_set = "#{attribute} = ?"
        update_value = value[:value]
      end

      [sql_set, update_value]
    end

    # TODO: delete when ActiveScaffold 3.5 is released and required
    def params_hash?(value)
      value.is_a?(Hash) || (Rails.version >= '5.0' && value.is_a?(ActionController::Parameters))
    end

    def update_attribute_values_from_params(columns, attributes)
      values = {}
      return values unless params_hash? attributes

      columns.each_column(for: new_model, crud_type: :update, flatten: true) do |column|
        next unless params_hash?(attributes[column.name]) && attributes[column.name][:operator] != 'NO_UPDATE'

        value = attributes[column.name]
        value[:value] = value[:operator] == 'NULL' ? nil : column_value_from_param_value(nil, column, value[:value])
        values[column.name] = {column: column, value: value}
      end
      values
    end

    # The default security delegates to ActiveRecordPermissions.
    # You may override the method to customize.
    def batch_update_authorized?(record = nil)
      authorized_for?(crud_type: :update)
    end

    def batch_update_ignore?(record = nil)
      false
    end

    def batch_update_value_for_numeric(column, record, calculation_info)
      current_value = record.send(column.name)
      operator = calculation_info[:operator]
      return current_value unless batch_update_operator?(operator, NUMERIC_OPERATORS)

      operand = self.class.condition_value_for_numeric(column, calculation_info[:value])
      operand = current_value / 100 * operand if calculation_info[:opt] == 'PERCENT'
      return operand if operator == 'REPLACE'
      return if operator == 'NULL' || current_value.blank?

      apply_numeric_operator(operator, current_value, operand)
    end

    def apply_numeric_operator(operator, current_value, operand)
      case operator
      when 'PLUS' then current_value + operand
      when 'MINUS' then current_value - operand
      when 'TIMES' then current_value * operand
      when 'DIVISION' then current_value / operand
      else
        current_value
      end
    end
    alias batch_update_value_for_integer batch_update_value_for_numeric
    alias batch_update_value_for_decimal batch_update_value_for_numeric
    alias batch_update_value_for_float batch_update_value_for_numeric

    def batch_update_all_value_for_numeric(column, calculation_info)
      operator = calculation_info[:operator]
      return unless batch_update_operator?(operator, NUMERIC_OPERATORS)

      model = active_scaffold_config.model
      connection = model.connection
      operand = model.quote_value(self.class.condition_value_for_numeric(column, calculation_info[:value]))
      if calculation_info[:opt] == 'PERCENT'
        operand = "#{connection.quote_column_name(column.name)} / 100.0 * #{operand}"
      end
      case calculation_info[:operator]
      when 'REPLACE' then operand
      when 'NULL' then model.quote_value(nil)
      when 'PLUS' then "#{connection.quote_column_name(column.name)} + #{operand}"
      when 'MINUS' then "#{connection.quote_column_name(column.name)} - #{operand}"
      when 'TIMES' then "#{connection.quote_column_name(column.name)} * #{operand}"
      when 'DIVISION' then "#{connection.quote_column_name(column.name)} / #{operand}"
      end
    end
    alias batch_update_all_value_for_integer batch_update_all_value_for_numeric
    alias batch_update_all_value_for_decimal batch_update_all_value_for_numeric
    alias batch_update_all_value_for_float batch_update_all_value_for_numeric

    def batch_update_value_for_date_picker(column, record, calculation_info)
      current_value = record.send(column.name)
      operator = calculation_info[:operator]
      return current_value unless batch_update_operator?(operator, DATE_OPERATORS)

      conversion = column.column.type == :date ? :to_date : :to_time
      operand = self.class.condition_value_for_datetime(column, calculation_info[:value], conversion)
      return operand if operator == 'REPLACE'
      return if operator == 'NULL'
      return current_value unless DATE_OPERATORS.include?(operator)

      trend_number = [calculation_info['number'].to_i, 1].max
      duration = trend_number.send(calculation_info['unit'].downcase.singularize.to_sym)
      operator == 'PLUS' ? current_value&.in(duration) : current_value&.ago(duration)
    end

    def batch_update_operator?(operator, type_operators)
      operator == 'NULL' || GENERIC_OPERATORS.include?(operator) || type_operators.include?(operator)
    end

    def override_batch_update_value(form_ui)
      method = "batch_update_value_for_#{form_ui}"
      method if respond_to? method, true
    end

    def override_batch_update_all_value(form_ui)
      method = "batch_update_all_value_for_#{form_ui}"
      method if respond_to? method, true
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
