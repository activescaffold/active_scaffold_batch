# frozen_string_literal: true

module ActiveScaffold::Config
  class BatchDestroy < ActiveScaffold::Config::Base
    self.crud_type = :delete

    def initialize(core_config)
      super
      @action_group ||= 'collection.batch.destroy'
      @process_mode = self.class.process_mode
    end

    # global level configuration
    # --------------------------
    # the ActionLink for this action
    cattr_accessor :link,
                   instance_accessor: false,
                   default: [
                     ActiveScaffold::DataStructures::ActionLink.new(
                       'batch_destroy', label: :listed, type: :collection, method: :delete, position: false,
                                        crud_type: :delete, confirm: :are_you_sure_to_delete,
                                        parameters: {batch_scope: 'LISTED'},
                                        security_method: :batch_destroy_authorized?
                     ),
                     ActiveScaffold::DataStructures::ActionLink.new(
                       'batch_destroy', label: :marked, type: :collection, method: :delete, position: false,
                                        crud_type: :delete, confirm: :are_you_sure_to_delete,
                                        parameters: {batch_scope: 'MARKED'},
                                        security_method: :batch_destroy_authorized?,
                                        ignore_method: :batch_destroy_marked_ignore?
                     )
                   ]

    # configures where the plugin itself is located. there is no instance version of this.
    cattr_accessor :plugin_directory,
                   instance_accessor: false,
                   default: File.expand_path(__FILE__).match(%r{(^.*)/lib/active_scaffold/config/batch_destroy.rb})[1]

    # configures how batch updates should be processed
    # :delete => standard activerecord delete including validations
    # :delete_all => updating in one sql call without activerecord instantiation and validation
    cattr_accessor :process_mode, instance_accessor: false, default: :delete

    # instance-level configuration
    # ----------------------------

    # see class accessor
    attr_accessor :process_mode

    # the ActionLink for this action
    attr_accessor :link
  end
end
