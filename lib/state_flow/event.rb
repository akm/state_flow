# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class Event < Entry
    include GuardClient
    include ActionClient
    
    def process(record)
      if guard = guard_for(record)
        guard.process(record)
      else
        action.process(record) if action
      end
      update_to_destination(record)
    end
    
  end

end
