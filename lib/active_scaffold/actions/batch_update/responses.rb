# frozen_string_literal: true

module ActiveScaffold::Actions::BatchUpdate::Responses
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

  def batch_update_respond_to_html
    if params[:iframe] == 'true'
      flash[:info] = as_(:batch_processing_successful) if batch_successful?
      do_refresh_list
      responds_to_parent do
        render action: 'on_batch_update.js', layout: false
      end
    elsif batch_successful?
      flash[:info] = as_(:updated_model, model: @record.to_label)
      return_to_main
    else
      render(action: 'batch_update')
    end
  end

  def batch_update_respond_to_js
    flash[:info] = as_(:batch_processing_successful) if batch_successful?
    do_refresh_list
    render action: 'on_batch_update'
  end
end
