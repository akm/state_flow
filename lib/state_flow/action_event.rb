# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class ActionEvent < Event
    attr_reader :matcher
    def initialize(origin, matcher, &block)
      @matcher = matcher
      super(origin, &block)
    end
  end

end
