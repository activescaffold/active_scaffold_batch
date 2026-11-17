# frozen_string_literal: true

require 'javascript_test_helper'

class BatchJavascriptTest < ActiveScaffold::TestSupport::Javascript::TestCase
  def fixture_html
    <<~HTML
      <div class="active-scaffold">
        <div class="batch-create-rows">
          <input name="num_records" value="3">
          <a id="batch-link" href="/batch">Add</a>
        </div>
        <div class="form-element">
          <select id="operator" class="as_batch_update_operator">
            <option value="REPLACE">Replace</option>
            <option value="NO_UPDATE">No update</option>
          </select>
          <input id="batch-value" value="value">
        </div>
      </div>
    HTML
  end

  def test_updates_batch_requests_and_operator_fields
    visit_javascript_fixture

    execute_script <<~JS
      window.batchSettings = {url: '/batch'};
      jQuery('#batch-link').trigger('ajax:beforeSend', [{}, window.batchSettings]);
    JS
    assert_javascript 'window.batchSettings.url === "/batch?num_records=3"'

    select 'No update', from: 'operator'
    assert_javascript 'document.querySelector("#batch-value").style.display === "none"'
    select 'Replace', from: 'operator'
    assert_javascript 'document.querySelector("#batch-value").style.display !== "none"'
    assert_no_javascript_errors
  end
end
