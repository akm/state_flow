module StateFlow
  autoload :Base, 'state_flow/base'
  autoload :Builder, 'state_flow/builder'

  autoload :Entry, 'state_flow/entry'
  autoload :State, 'state_flow/state'
  autoload :Selection, 'state_flow/selection'

  autoload :Transition, 'state_flow/transition'
  
  autoload :Action, 'state_flow/action'
  autoload :Event, 'state_flow/event'
  autoload :Guard, 'state_flow/guard'

  autoload :Log, 'state_flow/log'
  
  # autoload :ActiveRecord, 'state_flow/active_record'
  
  def self.included(mod)
    mod.module_eval do
    end
  end
  
end
