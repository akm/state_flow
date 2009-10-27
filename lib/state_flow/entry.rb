# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class Entry
    include ActionExecutable
    attr_reader :flow, :key

    def initialize(flow, key)
      @flow = flow
      @key = key.to_s.to_sym
    end
    
    def events
      @events ||= [];
    end

    def event_for(name)
      events.detect{|event| event.name == name}
    end

    def process(&block)
      value = flow.state_cd_by_key(key)
      find_options = {
        :order => "id asc",
        :conditions => ["#{flow.attr_name} = ?", value]
      }
      find_options[:lock] = action.lock if action.lock
      if record = flow.klass.find(:first, find_options)
        action.process(record, &block) if action
      end
    end
    
    def inspect
      result = "<#{self.class.name} @key=#{@key.inspect}"
      result << " @action=#{@action.inspect}" if @action
      if @events && !@events.empty?
        result << " @events=#{@events.sort_by{|event|event.name.to_s}.inspect}"
      end
      result << ">"
    end
  end

end
