# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class State
    include EventClient
    include GuardClient
    include ActionClient
    include ElementVisitable

    attr_reader :name, :flow, :parent
    attr_accessor :termination
    def initialize(flow_or_parent, name, &block)
      @name = name
      @parent = flow_or_parent if flow_or_parent.is_a?(State)
      @flow = flow_or_parent.is_a?(State) ? flow_or_parent.flow : flow_or_parent
      @concreate = @flow.state_cd_by_key(@name)
      instance_eval(&block) if block
    end
    
    def state(name, &block)
      result = State.new(self, name, &block)
      children << result
      result
    end
    alias_method :from, :state
    alias_method :group, :state
    alias_method :state_group, :state

    def termination(name = nil)
      result = name ? state(name) : self
      result.termination = true
      result
    end

    def children
      @children ||= []
    end

    def descendants
      [self, children.map{|c|c.descendants}].flatten
    end

    def include?(state_or_name)
      name = state_or_name.is_a?(State) ? state_or_name.name : state_or_name
      descendants.any?{|state| state.name == name}
    end

    def concrete?
      @concreate
    end

    private
    # for EventClient
    def origin
      self
    end

    public
    def process(context)
      context.trace(self)
      block = ancestors_exception_handled_proc(context) do
        guard = guard_for(context)
        return guard.process(context) if guard
        return action.process(context) if action
      end
      block.call
    end
    
    def ancestors_exception_handled_proc(context, &block)
      result = Proc.new{ exception_handling(context, &block) }
      parent ? parent.ancestors_exception_handled_proc(context, &result) : result
    end

    def name_path(separator = '>')
      result = []
      current = self
      while current
        result << current.name
        current = current.parent
      end
      result.reverse.join(separator)
    end

    def inspect
      "#<%s:%#x @name=%s>" % [self.class.name, self.object_id, name_path.inspect]
    end
    
  end

end
