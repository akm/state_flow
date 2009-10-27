# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class Event
    include ActionExecutable
    attr_reader :flow, :name

    def initialize(flow, name)
      @flow = flow
      @name = name.to_s.to_sym
    end

    def inspect
      result = "<#{self.class.name} @name=#{@name.inspect}"
      result << " @action=#{@action.inspect}" if @action
      result << ">"
    end
  end

end
