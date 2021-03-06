# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class Action < Element
    include ActionClient
    include EventClient
    include GuardClient

    attr_reader :method_name, :method_args
    def initialize(origin, method_name, *method_args, &block)
      @method_name, @method_args = method_name, method_args
      super(origin, &block)
    end
    
    def process(context)
      context.trace(self)
      context.mark_proceeding
      exception_handling(context) do
        result = context.record_send(method_name, *method_args)
        event = event_for_action_result(result)
        event.process(context) if event
        unless event
          action.process(context) if action
        end
        update_to_destination(context)
      end
    end

  end

end
