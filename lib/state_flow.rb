module StateFlow
  autoload :Base, 'state_flow/base'
  autoload :Context, 'state_flow/context'

  autoload :State, 'state_flow/state'
  
  autoload :Element, 'state_flow/element'
  autoload :ElementVisitable, 'state_flow/element_visitable'

  autoload :Action, 'state_flow/action'
  autoload :ActionClient, 'state_flow/action_client'

  autoload :Guard, 'state_flow/guard'
  autoload :GuardClient, 'state_flow/guard_client'
  autoload :NamedGuard, 'state_flow/named_guard'

  autoload :Event, 'state_flow/event'
  autoload :EventClient, 'state_flow/event_client'
  autoload :NamedEvent, 'state_flow/named_event'
  autoload :ActionEvent, 'state_flow/action_event'
  autoload :ExceptionHandler, 'state_flow/exception_handler'
  autoload :ExceptionHandlerClient, 'state_flow/exception_handler_client'

  autoload :Log, 'state_flow/log'
  
  # autoload :ActiveRecord, 'state_flow/active_record'
  
  def self.included(mod)
    mod.module_eval do
      extend(Base::ClientClassMethods)
    end
  end
  
end
