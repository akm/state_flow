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
        if origin.is_a?(State)
          named_event(name_or_matcher, &block)
        else
          action_event(name_or_matcher, &block)
        end
      end
    end

    def named_event(name, &block)
      result = NamedEvent.new(self, name, &block)
      events << result
      result
    end

    def action_event(matcher, &block)
      result = ActionEvent.new(self, matcher, &block)
      events << result
      result
    end

    def event_else(&block)
      if origin.is_a?(State)
        raise ArgumentError, "event_else can't be after/in a state but an action"
      end
      result = ActionEvent.new(self, ActionEvent::ELSE, &block)
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
      events.detect{|ev| ev.match?(result)}
    end

    def exception_handling(context)
      begin
        yield
      rescue Exception => exception
        context.exceptions << exception
        handlers = events.select{|ev| ev.is_a?(ExceptionHandler)}
        handlers.each do |handler|
          next unless handler.match?(exception)
          handler.process(context)
          break
        end
        raise exception unless context.recovered?(exception)
      end
    end

  end


end
