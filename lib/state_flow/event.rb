# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class Event < Entry
    include GuardClient
    include ActionClient
    
    def process(record)
      action.process(record) if action
      update_to_destination(record)
    end
    
  end

end
