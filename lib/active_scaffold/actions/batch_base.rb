module ActiveScaffold::Actions
  module BatchBase

    def self.included(base)
      base.helper_method :batch_scope
    end

    protected

    def batch_action(batch_action = :batch_base)
      process_action_link_action(batch_action) do
        process_batch
      end
    end

    def batch_scope
      if @batch_scope.nil? && params[:batch_scope]
        @batch_scope = params[:batch_scope] if ['LISTED', 'MARKED'].include?(params[:batch_scope])
        params.delete :batch_scope
      end
      @batch_scope
    end

    def error_records
      @error_records ||= []
    end

    def set_record_attribute(column, attribute, value)
      form_ui = column_form_ui(column)
      if form_ui && (method = send("override_#{action_name}_value", form_ui))
        @record.send("#{attribute}=", send(method, column, @record, value))
      else
        @record.send("#{attribute}=", action_name == 'batch_update' ? value[:value] : value)
      end
    end

    def column_form_ui(column)
      form_ui = column.form_ui
      form_ui = column.column.type if form_ui.nil? && column.column
      form_ui
    end

    # in case of an error we have to prepare @record object to have assigned all
    # defined batch_update values, however, do not set those ones with an override
    # these ones will manage on their own
    def prepare_error_record
      do_new
      send("#{action_name}_values").each do |attribute, value|
        form_ui = column_form_ui(value[:column])
        set_record_attribute(value[:column], attribute, value[:value]) unless form_ui && send("override_#{action_name}_value", form_ui)
      end
    end

    def batch_successful?
      error_records.empty?
    end

    def process_batch
      send("before_do_#{action_name}")
      send("#{action_name}_#{batch_scope.downcase}") if !batch_scope.nil? && respond_to?("#{action_name}_#{batch_scope.downcase}", true)
      prepare_error_record unless batch_successful?
    end

    def authorized_for_job?(record)
      if record.authorized_for?(:crud_type => active_scaffold_config.send(action_name).crud_type)
        true
      else
        record.errors.add(:base, as_(:no_authorization_for_action, :action => action_name))
        error_records << record
        false
      end
    end

    def temporary_id
      (Time.now.to_f*1000).to_i.to_s
    end

    def batch_base_respond_to_html
      if respond_to? "#{action_name}_respond_to_html", true
        send("#{action_name}_respond_to_html")
      else
        if params[:iframe]=='true' # was this an iframe post ?
          do_refresh_list
          responds_to_parent do
            render :action => 'on_batch_base.js', :layout => false
          end
        else # just a regular post
          flash[:info] = as_(:batch_processing_successful) if batch_successful?
          return_to_main
        end
      end
    end

    def batch_base_respond_to_js
      if respond_to? "#{action_name}_respond_to_js", true
        send("#{action_name}_respond_to_js")
      else  
        do_refresh_list
        render :action => "on_batch_base"
      end
    end

    def batch_base_respond_to_xml
      if respond_to? "#{action_name}_respond_to_xml", true
        send("#{action_name}_respond_to_xml")
      else
        render :xml => response_object.to_xml(:only => active_scaffold_config.send(action_name).columns.visible_columns_names), :content_type => Mime::XML, :status => response_status
      end
    end

    def batch_base_respond_to_json
      if respond_to? "#{action_name}_respond_to_json", true
        send("#{action_name}_respond_to_json")
      else
        render :text => response_object.to_json(:only => active_scaffold_config.send(action_name).columns.visible_columns_names), :content_type => Mime::JSON, :status => response_status
      end
    end

    def batch_base_respond_to_yaml
      if respond_to? "#{action_name}_respond_to_yaml", true
        send("#{action_name}_respond_to_yaml")
      else
        render :text => Hash.from_xml(response_object.to_xml(:only => active_scaffold_config.send(action_name).columns.visible_columns_names)).to_yaml, :content_type => Mime::YAML, :status => response_status
      end
    end

    def batch_base_formats
      if respond_to? "#{action_name}_formats", true
        send("#{action_name}_formats")
      else
        (default_formats + active_scaffold_config.formats + active_scaffold_config.send(action_name).formats).uniq
      end
    end
  end
end
