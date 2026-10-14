module ActiveScaffold
  module Helpers
    module DatepickerUpdateColumnHelpers
      def active_scaffold_update_date_picker(column, options)
        current_params = {value: nil, number: nil, unit: nil, operator: 'NO_UPDATE'}
        current_params.merge!(batch_update_values[column.name][:value].symbolize_keys) if batch_update_values.dig(column.name, :value)
        operator_options = active_scaffold_update_generic_operators(column)
        operator_options.concat(ActiveScaffold::Actions::BatchUpdate::DateOperators.collect {|comp| [as_(comp.downcase.to_sym), comp]}) if active_scaffold_config.batch_update.process_mode == :update
        options = options.merge(show: ['PLUS', 'MINUS'].exclude?(current_params[:operator]))
        operator_attributes = active_scaffold_batch_control_attributes(
          column, :select, :batch_update_operator,
          id: "#{options[:id]}_operator",
          class: 'text-input as_update_date_operator'
        )
        tags = []
        tags << select_tag("#{options[:name]}[operator]",
                           options_for_select(operator_options, current_params[:operator]),
                           operator_attributes)
        tags << active_scaffold_search_date_picker_field(column, options.merge(show: current_params[:operator] == 'REPLACE'), current_params[:value], 'value')
        tags << active_scaffold_update_date_bridge_trend_tag(column, current_params, options)
        tags.join("&nbsp;").html_safe
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
        controls = [
          text_field_tag("#{options[:name]}[number]", current_params[:number], number_attributes),
          select_tag(
            "#{options[:name]}[unit]",
            options_for_select(active_scaffold_search_datetime_trend_units(column), current_params[:unit]),
            unit_attributes
          )
        ]
        content_tag(
          :span,
          safe_join(controls, ' '),
          id: "#{options[:id]}_trend",
          class: 'search-date-trend',
          style: ('display: none' unless ['PLUS', 'MINUS'].include?(current_params[:operator]))
        )
      end
    end
  end
end
