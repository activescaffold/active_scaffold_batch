# frozen_string_literal: true

module ActiveScaffold::Actions::BatchCreate::Records
  protected

  def batch_create_by_records
    if @batch_create_by_records.nil? && marked_records_parent
      column = active_scaffold_config.columns[batch_create_by_column.to_sym]
      @batch_create_by_records = records_for_batch_create_column(column)
    end
    @batch_create_by_records || []
  end

  def records_for_batch_create_column(column)
    if column.association.polymorphic?
      active_scaffold_config_for(params[:batch_create_by].singularize).model.find(marked_records_parent.keys)
    else
      column_plural_assocation_value_from_value(column, marked_records_parent.keys)
    end
  end

  def new_batch_create_record(created_by)
    new_model
  end

  def create_record_in_batch(created_by)
    prepare_batch_create_record(created_by)
    return unless authorized_for_job?(@record)

    validate_or_save_batch_create_record
    finalize_batch_create_record(created_by)
  end

  def prepare_batch_create_record(created_by)
    @successful = nil
    @record = new_batch_create_record(created_by)
    @record.send("#{batch_create_by_column}=", created_by)
    batch_create_values.each do |attribute, value|
      set_record_attribute(value[:column], attribute, value[:value])
    end
  end

  def validate_or_save_batch_create_record
    if validate_first?
      self.successful = [@record.valid?, @record.associated_valid?].all?
    else
      save_batch_create_record
    end
  end

  def save_batch_create_record
    create_save(@record)
    self.successful = @record.persisted?
  rescue ActiveRecord::ActiveRecordError => e
    @record.errors.add(:base, e.message) if @record.errors.empty?
    self.successful = false
  end

  def finalize_batch_create_record(created_by)
    if successful?
      marked_records_parent.delete(created_by.id.to_s) if batch_scope == 'MARKED' && marked_records_parent
    else
      normalize_batch_create_errors
    end
    error_records << @record unless successful? && !run_in_transaction?
  end

  def normalize_batch_create_errors
    new_errors = @record.errors.messages[batch_create_by_column].map do |error|
      "#{@record.send(batch_create_by_column)} #{error}"
    end
    @record.errors.delete(batch_create_by_column)
    new_errors.each { |error| @record.errors.add batch_create_by_column, error }
  end

  def create_attribute_values_from_params(columns, attributes)
    values = {}
    parent_record = active_scaffold_config.model.new
    columns.each_column(for: active_scaffold_config.model, crud_type: :create, flatten: true) do |column|
      next unless attributes.key?(column.name)

      if column == batch_create_by_column.to_sym
        @batch_create_by_records = batch_values_for_column(column, attributes[column.name])
      else
        value = column_value_from_param_value(parent_record, column, attributes[column.name])
        values[column.name] = {column: column, value: value}
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
end
