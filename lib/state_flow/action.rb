# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class Action < Entry
    include ActionClient
    include EventClient
    include GuardClient

    attr_reader :method_name, :method_args
    def initialize(origin, method_name, *method_args, &block)
      @method_name, @method_args = method_name, method_args
      super(origin, &block)
    end
    
    def process(record)
      begin
        result = record.send(method_name, *method_args)
        event = event_for_action_result(result)
        if event
          event.process(record) 
        elsif action
          action.process(record)
        end
        update_to_destination(record)
      rescue Exception => err
        raise err
      end
    end
  end

end
