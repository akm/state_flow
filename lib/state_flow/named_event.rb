# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class NamedEvent < Event
    def initialize(origin, name, &block)
      @name = name
      super(origin, &block)
    end
  end

end
