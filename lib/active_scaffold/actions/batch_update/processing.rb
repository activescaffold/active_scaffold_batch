# frozen_string_literal: true

module ActiveScaffold::Actions::BatchUpdate::Processing
  protected

  def batch_update_listed
    case active_scaffold_config.batch_update.process_mode
    when :update
      each_record_in_scope { |record| update_record_in_batch(record) if authorized_for_job?(record) }
    when :update_all
      update_all_listed_records
    else
      log_unknown_batch_update_mode
    end
  end

  def update_all_listed_records
    updates = updates_for_update_all
    return if updates.first.empty?

    do_search if respond_to? :do_search, true
    # all_conditions might fail cause joins are not working in update_all.
    # update_all is the explicitly configured batch processing mode.
    active_scaffold_config.model.update_all(updates, all_conditions) # rubocop:disable Rails/SkipsModelValidations
  end

  def batch_update_marked
    case active_scaffold_config.batch_update.process_mode
    when :update
      each_marked_record { |record| update_record_in_batch(record) if authorized_for_job?(record) }
    when :update_all
      update_all_marked_records
    else
      log_unknown_batch_update_mode
    end
  end

  def update_all_marked_records
    updates = updates_for_update_all
    return if updates.first.empty?

    model = active_scaffold_config.model
    # update_all is the explicitly configured batch processing mode.
    model.where(model.primary_key => marked_records.to_a).update_all(updates) # rubocop:disable Rails/SkipsModelValidations
    do_demark_all
  end

  def log_unknown_batch_update_mode
    Rails.logger.error "Unknown process_mode: #{active_scaffold_config.batch_update.process_mode} " \
                       'for action batch_update'
  end

  def updates_for_update_all
    update_all = [[]]
    batch_update_values.each do |attribute, value|
      append_update_all_attribute(update_all, attribute, value)
    end
    add_timestamps_to_update_all(update_all) if update_all.first.any?
    update_all[0] = update_all.first.join(',')
    update_all
  end

  def append_update_all_attribute(update_all, attribute, value)
    sql_set, update_value = get_update_all_attribute(value[:column], attribute, value[:value])
    return if sql_set.nil?

    update_all.first << sql_set
    update_all << update_value if update_value.present?
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
    method = override_batch_update_all_value(form_ui) if form_ui
    return default_update_all_attribute(attribute, value) unless method

    custom_update_all_attribute(method, column, attribute, value)
  end

  def default_update_all_attribute(attribute, value)
    ["#{attribute} = ?", value[:value]]
  end

  def custom_update_all_attribute(method, column, attribute, value)
    update_value = send(method, column, value)
    return [nil, nil] if update_value.nil?

    ["#{attribute} = #{update_value}", nil]
  end

  def update_attribute_values_from_params(columns, attributes)
    values = {}
    return values unless params_hash? attributes

    columns.each_column(for: new_model, crud_type: :update, flatten: true) do |column|
      next unless batch_update_attribute?(attributes[column.name])

      value = attributes[column.name]
      value[:value] = batch_update_attribute_value(column, value)
      values[column.name] = {column: column, value: value}
    end
    values
  end

  def batch_update_attribute?(value)
    params_hash?(value) && value[:operator] != 'NO_UPDATE'
  end

  def batch_update_attribute_value(column, value)
    return if value[:operator] == 'NULL'

    column_value_from_param_value(nil, column, value[:value])
  end
end
