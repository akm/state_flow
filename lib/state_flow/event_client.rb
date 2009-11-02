# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  module EventClient
    def events
      @events ||= []
    end

    def event(name_or_matcher, &block)
      klass = origin.is_a?(State) ? NamedEvent : ActionEvent
      result = klass.new(self, name_or_matcher, &block) 
      events << result
      result
    end

    def event_else(&block)
      result = Event.new(self, &block) 
      events << result
      result
    end

    def recover(*args, &block)
      result = Recovery.new(self, *args, &block)
      events << result
      result
    end

  end


end
