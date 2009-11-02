require 'state_flow'
module StateFlow

  module GuardClient
    def guards
      @guards ||= []
    end

    def guard(method_name, &block)
      result = NamedGuard.new(self, method_name, &block)
      guards << result
      result
    end

    def guard_else(&block)
      result = Guard.new(self, &block)
      guards << result
      result
    end

    
  end

end

