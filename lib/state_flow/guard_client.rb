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
    
    def guard_for(record)
      guards.detect{|guard| guard.match?(record)}
    end
    
  end

end

