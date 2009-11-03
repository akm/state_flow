# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class Entry
    include EntryVisitable

    attr_reader :origin
    attr_reader :destination
    def initialize(origin, &block)
      @origin = origin
      instance_eval(&block) if block
    end

    def to(destination)
      @destination = destination
    end

    def flow
      @flow || origin.flow
    end

    def state
      origin.is_a?(State) ? origin : origin.state
    end

    def update_to_destination(context)
      return unless destination
      context.record_send("#{flow.attr_key_name}=", destination)
    end

    
  end

end
