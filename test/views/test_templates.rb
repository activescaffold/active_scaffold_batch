# frozen_string_literal: true

require 'test_helper'

class TemplatesTest < Minitest::Test
  VIEW_PATH = File.expand_path('../../app/views', __dir__)

  Action = Struct.new(:crud_type)
  BatchAction = Struct.new(:label, :columns, :layout)
  Config = Struct.new(:batch_create, :batch_update, :columns, :model) do
    def label(count:)
      "#{count} records"
    end
  end
  Column = Struct.new(:name, :association, :css_class, :required, :label) do
    def required?
      required
    end
  end

  class Columns
    attr_accessor :collapsed
    attr_reader :action

    def initialize(columns = [])
      @columns = columns
      @action = Action.new(:create)
      @collapsed = false
    end

    def each_column(**, &)
      @columns.each(&)
    end
  end

  class Record
    attr_accessor :name

    def self.model_name
      Struct.new(:human).new('Record')
    end

    def initialize(name = 'Example')
      @name = name
    end

    def new_record?
      true
    end

    def to_label
      name
    end
  end

  class Controller
    attr_accessor :successful

    def batch_successful?
      successful
    end
  end

  class ViewContext < ActionView::Base
    attr_accessor :batch_create_by_column, :batch_scope, :controller, :params
    attr_reader :flash, :render_calls

    def initialize(lookup_context, assigns, controller)
      super
      @render_calls = []
      @params = {controller: 'records'}
      @flash = {}
      @batch_create_by_column = :name
      @batch_scope = 'LISTED'
      @controller = Controller.new
    end

    def render_root(options)
      @render_root = true
      render(options)
    ensure
      @render_root = false
    end

    def render(options = {}, locals = {}, &)
      if @render_root
        @render_root = false
        super
      else
        render_calls << [options, locals]
        '[rendered]'.html_safe
      end
    end

    def active_scaffold_config
      columns = Columns.new
      @active_scaffold_config ||=
        Config.new(BatchAction.new('Create records', columns, :vertical),
                   BatchAction.new('Update records', columns, nil),
                   {name: Column.new(:name)}, Record)
    end

    def request
      Struct.new(:xhr?).new(false)
    end

    def as_(key, **)
      key.to_s
    end

    def as_element(_name, content = nil, **, &block)
      content = capture(&block) if block
      content.to_s
    end

    def as_element_attributes(_name, **options)
      options
    end

    def active_scaffold_batch_create_by_column(column, scope, object:)
      "batch-column:#{column}:#{scope}:#{object.name}"
    end

    def active_scaffold_update_for(column, scope, object:)
      "update-column:#{column.name}:#{scope}:#{object.name}"
    end

    def form_attribute(column, _record, _scope, field:)
      "attribute:#{column.name}:#{field}"
    end

    def form_attribute_html(_column, label, field, *)
      "#{label}:#{field}"
    end

    def active_scaffold_update_scope_select_options
      [%w[Listed LISTED], %w[Marked MARKED]]
    end

    def active_scaffold_update_scope_select(*)
      'scope-select'
    end

    def active_scaffold_update_scope_select_hidden?(*)
      false
    end

    def active_scaffold_batch_control_attributes(*)
      {}
    end

    def active_scaffold_input_text_options(options)
      options
    end

    def batch_create_multiple_layout
      'batch_create_form_vertical'
    end

    def params_for(**options)
      options
    end

    def link_to(label, target, _options = {})
      %(<a href="#{target}">#{label}</a>)
    end

    def element_form_id(action:)
      "records-#{action}"
    end

    def column_renders_as(_column)
      :field
    end

    def render_subsection(*)
      'subsection'
    end

    def active_scaffold_content_id
      'records-content'
    end

    def controller_id(name)
      "#{name}-controller"
    end

    def active_scaffold_error_messages_for(record, **)
      "errors:#{record.to_label}"
    end

    def escape_javascript(value)
      value.to_s
    end
  end

  def setup
    lookup_context = ActionView::LookupContext.new([VIEW_PATH])
    assigns = {
      record: Record.new,
      records: {'0' => Record.new},
      error_records: []
    }
    @view = ViewContext.with_empty_template_cache.new(lookup_context, assigns, nil)
  end

  def test_executes_every_batch_partial
    columns = Columns.new
    record = Record.new
    partials = {
      batch_create_form: {},
      batch_create_form_attribute: {column: Column.new(:name), record: record},
      batch_create_form_body: {columns: columns, scope: nil, form_action: :batch_create},
      batch_create_form_footer: {},
      batch_create_form_horizontal: {columns: columns, form_action: :batch_create, records: {'0' => record}},
      batch_create_form_horizontal_header: {columns: columns},
      batch_create_form_horizontal_record: {
        columns: columns, form_action: :batch_create, scope: '[0]', first: true, record: record
      },
      batch_create_form_multiple: {columns: columns, form_action: :batch_create, scope: '0'},
      batch_create_form_vertical: {columns: columns, form_action: :batch_create, records: {'0' => record}},
      batch_create_form_vertical_record: {
        columns: columns, form_action: :batch_create, scope: '[0]', first: true, record: record
      },
      batch_update_form: {},
      batch_update_form_attribute: {column: Column.new(:name), record: record},
      batch_update_form_attribute_scope: {},
      batch_update_form_body: {columns: columns, scope: nil, form_action: :batch_update},
      form_messages: {}
    }

    partials.each do |name, locals|
      output = @view.render_root(partial: "active_scaffold_overrides/#{name}", locals: locals)
      refute_nil output, "expected #{name} to render"
    end
  end

  def test_executes_every_batch_page_and_javascript_template
    @view.controller.successful = true
    templates = %i[
      batch_add batch_create batch_update on_batch_base on_batch_create on_batch_update
    ]

    templates.each do |name|
      output = @view.render_root(template: "active_scaffold_overrides/#{name}")
      refute_nil output, "expected #{name} to render"
    end
  end

  def test_executes_failed_batch_javascript_responses
    @view.controller.successful = false

    %i[on_batch_create on_batch_update].each do |name|
      output = @view.render_root(template: "active_scaffold_overrides/#{name}")
      assert_includes output, 'ActiveScaffold'
    end
  end
end
