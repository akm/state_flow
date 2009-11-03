# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class ActionEvent < Event
    ELSE = Object.new

    attr_reader :matcher
    def initialize(origin, matcher, &block)
      @matcher = matcher
      super(origin, &block)
    end

    def match?(action_result)
      return true if matcher == ActionEvent::ELSE
      matcher === action_result
    end

  end

end
