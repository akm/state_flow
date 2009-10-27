# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class NamedAction < Action
    attr_reader :name
    def initialize(flow, name)
      super(flow)
      @name = name.to_s.to_sym
    end

    def proceed
      flow.process_with_log(self.record, success_key, failure_key) do
        self.record.send(name)
      end
    end
  end

end
