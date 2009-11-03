# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class Event < Entry
    include GuardClient
    include ActionClient
    
    def process(context)
      if guard = guard_for(context)
        guard.process(context)
      else
        action.process(context) if action
      end
      update_to_destination(context)
    end
    
  end

end
