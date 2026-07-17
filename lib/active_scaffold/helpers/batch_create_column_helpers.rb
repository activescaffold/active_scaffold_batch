module ActiveScaffold
  module Helpers
    # Helpers that assist with the rendering of a Form Column
    module BatchCreateColumnHelpers
      # This method decides which input to use for the given column.
      # It does not do any rendering. It only decides which method is responsible for rendering.
      def active_scaffold_batch_create_by_column(column, scope = nil, options = {})
        options = active_scaffold_input_options(column, scope, options)

        ui_options = column.form_ui_options || column.options
        if column.form_ui == :record_select
          active_scaffold_record_select(options[:object], column, options, batch_create_by_records, true, ui_options: ui_options)
        elsif column.association
          active_scaffold_batch_create_singular_association(column, options, ui_options: ui_options)
        else
          text_area_tag(column.name, params[:record] ? params[:record][column.name] : '', options.merge(column.options[:html_options] || {}))
        end

      end

      def active_scaffold_batch_create_singular_association(column, html_options, ui_options: column.options)
        associated_options = batch_create_by_records.collect {|r| r.id}
        active_scaffold_input_singular_association(column, html_options.merge(multiple: true, associated: associated_options), {include_blank: false}, ui_options: ui_options)
      end

      def batch_create_multiple_layout
        "batch_create_form_#{active_scaffold_config.batch_create.layout}"
      end

      def current_form_columns(record, scope, subform_controller = nil)
        columns = super
        return columns if columns
        if %i[batch_new batch_create].include? action_name.to_sym
          active_scaffold_config.batch_create.columns.visible_columns_names
        elsif %i[batch_edit batch_update].include? action_name.to_sym
          active_scaffold_config.batch_update.columns.visible_columns_names
        end
      end
    end
  end
end
