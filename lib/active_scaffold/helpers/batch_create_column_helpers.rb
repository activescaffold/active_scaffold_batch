module ActiveScaffold
  module Helpers
    # Helpers that assist with the rendering of a Form Column
    module BatchCreateColumnHelpers
      # This method decides which input to use for the given column.
      # It does not do any rendering. It only decides which method is responsible for rendering.
      def active_scaffold_batch_create_by_column(column, scope = nil, options = {})
        options = active_scaffold_input_options(column, scope, options)

        if column.form_ui == :record_select
          active_scaffold_record_select(column, options, batch_create_by_records, true)
        elsif column.association
          active_scaffold_batch_create_singular_association(column, options)
        else
          text_area_tag(column.name, params[:record] ? params[:record][column.name] : '', options.merge(column.options[:html_options] || {}))
        end

      end

      def active_scaffold_batch_create_singular_association(column, html_options)
        associated_options = batch_create_by_records.collect {|r| r.id}
        select_options = sorted_association_options_find(column.association, nil, html_options.delete(:record))
        html_options.update(column.options[:html_options] || {})
        options = {}
        options.update(column.options)
        html_options[:name] = "#{html_options[:name]}[]" 
        html_options[:multiple] = true
        select_tag(column.name, options_from_collection_for_select(select_options.uniq, :id, column.options[:label_method] || :to_label, associated_options), html_options)
      end

      def batch_create_multiple_remove_link
        link_to as_(:remove), '#', :class => 'remove'
      end

      def batch_create_multiple_layout
        "batch_create_form_#{active_scaffold_config.batch_create.layout}"
      end
    end
  end
end
