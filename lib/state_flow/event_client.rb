# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  module EventClient
    def events
      @events ||= []
    end

    def event(*name_or_matcher_or_exceptions, &block)
      options = name_or_matcher_or_exceptions.extract_options!
      if name_or_matcher_or_exceptions.all?{|v| v.is_a?(Class) && v <= Exception}
        handle_exception(*name_or_matcher_or_exceptions.push(options), &block)
      else
        if name_or_matcher_or_exceptions.length > 1
          raise ArgumentError, "event(event_name) or event(action_result) or event(Exception1, Exception2...)"
        end
        name_or_matcher = name_or_matcher_or_exceptions.first
        klass = origin.is_a?(State) ? NamedEvent : ActionEvent
        result = klass.new(self, name_or_matcher, &block)
        events << result
        result
      end
    end

    def event_else(&block)
      result = Event.new(self, &block) 
      events << result
      result
    end

    def handle_exception(*args, &block)
      result = ExceptionHandler.new(self, *args, &block)
      events << result
      result
    end

    def recover(*args, &block)
      options = {
        :recovering => true, 
        :rolling_back => true, 
        :logging => :error
      }.update(args.extract_options!)
      handle_exception(*(args << options), &block)
    end

    def event_for_action_result(result)
      events.select do |event|
        event.is_a?(ActionEvent) || (event.class == Event)
      end
      events.detect do |ev|
        ev.respond_to?(:matcher) ? (ev.matcher === result) : true
      end
    end

    def exception_handling(context)
      begin
        yield
      rescue Exception => exception
        recovered = false
        handlers = events.select{|ev| ev.is_a?(ExceptionHandler)}
        handlers.each do |handler|
          next unless handler.match?(exception)
          handler.process(context)
          recovered = true if handler.recovering
          break
        end
        raise exception unless recovered
      end
    end

  end


end
