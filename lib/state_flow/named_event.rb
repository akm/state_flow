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
        named_events = []
        flow.all_states.each do |state_name, state|
          state.visit do |event|
            named_events << event if event.is_a?(NamedEvent)
            [:events, :guards, :action]
          end
        end
        method_name_to_events = {}
        named_events.each do |ev|
          method_name_to_events[ev.name] ||= []
          method_name_to_events[ev.name] << ev
        end
        method_name_to_events.each do |name, events|
          flow.klass.module_eval do
            # イベントを通知するときに呼び出されるメソッド
            define_method(name) do |*args|
              result = nil
              events.each do |event|
                if event.state.include?(self.send(flow.attr_key_name))
                  context = flow.prepare_context(self, args.first)
                  event.process(context)
                  context.save_record_if_need
                  result = context
                  break
                end
              end
              result # return
            end

          end
        end
      end
      
    end

  end

end
