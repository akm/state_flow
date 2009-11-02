# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class NamedGuard < Guard
    attr_reader :name
    def initialize(origin, name, &block)
      @name = name
      super(origin, &block)
    end
  end

end
