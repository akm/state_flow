# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class Recovery < Event
    def initialize(origin, exceptions, &block)
      @exceptions = exceptions
      super(origin, &block)
    end
  end

end
