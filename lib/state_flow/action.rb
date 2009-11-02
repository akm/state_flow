# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class Action < Entry
    include ActionClient
    include EventClient
    include GuardClient

    attr_reader :method_name, :method_args
    def initialize(origin, method_name, *method_args, &block)
      @method_name, @method_args = method_name, method_args
      super(origin, &block)
    end
    
  end

end
