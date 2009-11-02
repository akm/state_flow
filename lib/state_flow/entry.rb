# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class Entry
    attr_reader :origin
    attr_reader :destination
    def initialize(origin, &block)
      @origin = origin
      instance_eval(&block) if block
    end

    def to(destination)
      @destination = destination
    end
  end

end
