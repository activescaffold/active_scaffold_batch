# frozen_string_literal: true

module ActiveScaffold::Actions::BatchCreate::Responses
  protected

  def batch_new_respond_to_html
    if batch_successful?
      render(action: 'batch_create')
    else
      return_to_main
    end
  end

  def batch_new_respond_to_js
    render(partial: 'batch_create_form')
  end

  def batch_add_respond_to_js
    render
  end

  def batch_create_respond_to_html
    if params[:iframe] == 'true'
      do_refresh_list
      responds_to_parent do
        render action: 'on_batch_create.js', layout: false
      end
    elsif batch_successful?
      return_to_main
    else
      render(action: 'batch_create')
    end
  end

  def batch_create_respond_to_js
    do_refresh_list
    render action: 'on_batch_create'
  end
end
