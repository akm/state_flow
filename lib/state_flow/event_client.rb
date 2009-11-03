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

    def event_for_action_result(result)
      events.select do |event|
        event.is_a?(ActionEvent) || (event.class == Event)
      end
      events.detect do |ev|
        ev.respond_to?(:matcher) ? (ev.matcher === result) : true
      end
    end

  end


end
