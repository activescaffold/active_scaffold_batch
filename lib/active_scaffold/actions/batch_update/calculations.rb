# frozen_string_literal: true

module ActiveScaffold::Actions::BatchUpdate::Calculations
  protected

  def batch_update_value_for_numeric(column, record, calculation_info)
    current_value = record.send(column.name)
    operator = calculation_info[:operator]
    numeric_operators = ActiveScaffold::Actions::BatchUpdate::NUMERIC_OPERATORS
    return current_value unless batch_update_operator?(operator, numeric_operators)

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
    numeric_operators = ActiveScaffold::Actions::BatchUpdate::NUMERIC_OPERATORS
    return unless batch_update_operator?(operator, numeric_operators)

    model = active_scaffold_config.model
    operand = numeric_update_all_operand(model, column, calculation_info)
    numeric_update_all_expression(model, column, operator, operand)
  end

  def numeric_update_all_operand(model, column, calculation_info)
    operand = model.quote_value(self.class.condition_value_for_numeric(column, calculation_info[:value]))
    return operand unless calculation_info[:opt] == 'PERCENT'

    quoted_column = model.connection.quote_column_name(column.name)
    "#{quoted_column} / 100.0 * #{operand}"
  end

  def numeric_update_all_expression(model, column, operator, operand)
    quoted_column = model.connection.quote_column_name(column.name)
    case operator
    when 'REPLACE' then operand
    when 'NULL' then model.quote_value(nil)
    when 'PLUS' then "#{quoted_column} + #{operand}"
    when 'MINUS' then "#{quoted_column} - #{operand}"
    when 'TIMES' then "#{quoted_column} * #{operand}"
    when 'DIVISION' then "#{quoted_column} / #{operand}"
    end
  end
  alias batch_update_all_value_for_integer batch_update_all_value_for_numeric
  alias batch_update_all_value_for_decimal batch_update_all_value_for_numeric
  alias batch_update_all_value_for_float batch_update_all_value_for_numeric

  def batch_update_value_for_date_picker(column, record, calculation_info)
    current_value = record.send(column.name)
    operator = calculation_info[:operator]
    date_operators = ActiveScaffold::Actions::BatchUpdate::DATE_OPERATORS
    return current_value unless batch_update_operator?(operator, date_operators)

    conversion = column.column.type == :date ? :to_date : :to_time
    operand = self.class.condition_value_for_datetime(column, calculation_info[:value], conversion)
    return operand if operator == 'REPLACE'
    return if operator == 'NULL'
    return current_value unless date_operators.include?(operator)

    apply_date_operator(operator, current_value, calculation_info)
  end

  def apply_date_operator(operator, current_value, calculation_info)
    trend_number = [calculation_info['number'].to_i, 1].max
    duration = trend_number.send(calculation_info['unit'].downcase.singularize.to_sym)
    operator == 'PLUS' ? current_value&.in(duration) : current_value&.ago(duration)
  end

  def batch_update_operator?(operator, type_operators)
    generic_operators = ActiveScaffold::Actions::BatchUpdate::GENERIC_OPERATORS
    operator == 'NULL' || generic_operators.include?(operator) || type_operators.include?(operator)
  end

  def override_batch_update_value(form_ui)
    method = "batch_update_value_for_#{form_ui}"
    method if respond_to? method, true
  end

  def override_batch_update_all_value(form_ui)
    method = "batch_update_all_value_for_#{form_ui}"
    method if respond_to? method, true
  end
end
