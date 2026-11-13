# frozen_string_literal: true

module ActiveScaffold
  module Helpers
    module DatepickerUpdateColumnHelpers
      def active_scaffold_update_date_picker(column, options)
        defaults = {value: nil, number: nil, unit: nil, operator: 'NO_UPDATE'}
        current_params = active_scaffold_update_values(column, defaults)
        operator_options = active_scaffold_update_date_operator_options(column)
        options = options.merge(show: %w[PLUS MINUS].exclude?(current_params[:operator]))
        operator_attributes = active_scaffold_update_operator_attributes(
          column, options, 'text-input as_update_date_operator'
        )
        controls = [
          select_tag(
            "#{options[:name]}[operator]",
            options_for_select(operator_options, current_params[:operator]),
            operator_attributes
          ),
          active_scaffold_search_date_picker_field(
            column, options.merge(show: current_params[:operator] == 'REPLACE'), current_params[:value], 'value'
          ),
          active_scaffold_update_date_bridge_trend_tag(column, current_params, options)
        ]
        safe_join(controls, ' ')
      end

      def active_scaffold_update_date_operator_options(column)
        operators = active_scaffold_update_generic_operators(column)
        return operators unless active_scaffold_config.batch_update.process_mode == :update

        operators + active_scaffold_update_options_for(ActiveScaffold::Actions::BatchUpdate::DATE_OPERATORS)
      end

      def active_scaffold_update_date_bridge_trend_tag(column, current_params, options)
        number_attributes = active_scaffold_batch_control_attributes(
          column, :text, :batch_update_date_amount,
          class: 'text-input', size: 10, autocomplete: 'off'
        )
        unit_attributes = active_scaffold_batch_control_attributes(
          column, :select, :batch_update_date_unit,
          class: 'text-input'
        )
        unit_options = options_for_select(active_scaffold_search_datetime_trend_units(column), current_params[:unit])
        controls = [
          text_field_tag("#{options[:name]}[number]", current_params[:number], number_attributes),
          select_tag("#{options[:name]}[unit]", unit_options, unit_attributes)
        ]
        content_tag(
          :span,
          safe_join(controls, ' '),
          id: "#{options[:id]}_trend",
          class: 'search-date-trend',
          style: ('display: none' unless %w[PLUS MINUS].include?(current_params[:operator]))
        )
      end
    end
  end
end
