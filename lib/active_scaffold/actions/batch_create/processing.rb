# frozen_string_literal: true

module ActiveScaffold::Actions::BatchCreate::Processing
  protected

  def marked_records_parent
    if @marked_records_parent.nil?
      @marked_records_parent = load_marked_records_parent
    end
    @marked_records_parent
  end

  def load_marked_records_parent
    return false unless params[:batch_create_by]

    session_parent = active_scaffold_session_storage(params[:batch_create_by])
    session_parent['marked_records'] || {}
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
    return unless batch_successful? || created_records.positive?

    flash[:info] = as_(
      :some_records_created,
      count: created_records,
      model: active_scaffold_config.label(count: created_records)
    )
  end

  def batch_create_listed
    run_in_transaction_if_enabled do
      processed_records = created_records = 0
      case active_scaffold_config.batch_create.process_mode
      when :create
        batch_create_by_records.each do |batch_record|
          create_record_in_batch(batch_record)
          created_records += 1 if successful?
          processed_records += 1
        end
      else
        Rails.logger.error "Unknown process_mode: #{active_scaffold_config.batch_create.process_mode} for " \
                           'action batch_create'
      end
      [processed_records, created_records]
    end
  end
  alias batch_create_marked batch_create_listed

  def batch_create_multiple
    run_in_transaction_if_enabled do
      @error_records = {}
      processed_records = created_records = 0
      params[:record].each do |scope, record_hash|
        do_create(attributes: record_hash, skip_save: validate_first?)
        error_records[scope] = @record unless successful? && !run_in_transaction?
        created_records += 1 if successful?
        processed_records += 1
      end
      [processed_records, created_records]
    end
  end
end
