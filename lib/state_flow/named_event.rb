# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class NamedEvent < Event
    attr_reader :name
    def initialize(origin, name, &block)
      @name = name
      super(origin, &block)
    end

    class << self
      def build_event_methods(flow)
        dispatcher = [:events]
        named_events = []
        flow.all_states.each do |state_name, state|
          state.events.each do |event|
            named_events << event if event.is_a?(NamedEvent)
            dispatcher
          end
        end
        puts named_events.map(&:name)
        method_name_to_events = {}
        named_events.each do |ev|
          method_name_to_events[ev.name] ||= []
          method_name_to_events[ev.name] << ev
        end
        method_name_to_events.each do |name, events|
          flow.klass.module_eval do
            define_method(name) do |*args|
              
              
            end
          end
        end
      end
      
    end

  end

end
