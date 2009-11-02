# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  module ActionClient
    def action(method_name = nil, *method_args, &block)
      if method_name
        result = Action.new(self, method_name, *method_args, &block)
        @action = result
        result
      else
        @action
      end
    end
  end
end
