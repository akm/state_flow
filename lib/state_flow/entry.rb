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

    def flow
      @flow || origin.flow
    end

    def update_to_destination(context)
      return unless destination
      context.record_send("#{flow.attr_key_name}=", destination)
    end

    # Visitorパターン
    def visit(&block)
      results = block.call(self)
      (results || [:events, :guards, :action]).each do |entries_name|
        next if [:events, :guards, :action].include?(entries_name) && !respond_to?(entries_name)
        entries = send(entries_name)
        entries = [entries] unless entries.is_a?(Array)
        entries.each do |entry|
          entry.visit(&block)
        end
      end
    end
    
  end

end
