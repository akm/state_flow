# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class State
    include EventClient
    include GuardClient
    include ActionClient

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

    def concrete?
      @concreate
    end

    

    private
    # for EventClient
    def origin
      self
    end


  end

end
