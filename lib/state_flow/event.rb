# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class Event < Element
    include GuardClient
    include ActionClient
    include ExceptionHandlerClient
    
    def process(context)
      context.trace(self)
      if guard = guard_for(context)
        guard.process(context)
      else
        action.process(context) if action
      end
      update_to_destination(context)
    end
  end

end
