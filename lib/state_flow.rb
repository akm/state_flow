module StateFlow
  autoload :Base, 'state_flow/base'
  autoload :Builder, 'state_flow/builder'
  autoload :Action, 'state_flow/action'
  autoload :NamedAction, 'state_flow/named_action'
  autoload :Event, 'state_flow/event'
  autoload :Entry, 'state_flow/entry'
  autoload :Log, 'state_flow/log'
  
  # autoload :ActiveRecord, 'state_flow/active_record'
  
  def self.included(mod)
    mod.module_eval do
      extend ::StateFlow::Builder::ClientClassMethods
      extend ::StateFlow::Base::ClassMethods
      # include ::StateFlow::ActiveRecord if mod.ancestors.map{|m| m.name}.include?('ActiveRecord::Base')
    end
  end
  
end
