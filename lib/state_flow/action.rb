# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class Action
    attr_reader :flow
    attr_accessor :success_key
    attr_accessor :failure_key
    attr_accessor :lock, :if, :unless

    def initialize(flow)
      @flow = flow
      @record_key_on_thread = "#{self.class.name}_#{self.object_id}_record"
    end

    def record
      Thread.current[@record_key_on_thread]
    end

    def record=(value)
      Thread.current[@record_key_on_thread] = value
    end

    def process(record)
      return if self.if && !call_or_send(self.if, record)
      return if self.unless && call_or_send(self.unless, record)
      self.record = record
      begin
        block_given? ? yield(self) : proceed
      ensure
        self.record = nil
      end
    end
    
    def proceed
      flow.process_with_log(self.record, success_key, failure_key)
    end
    
    def call_or_send(filter, record)
      filter.respond_to?(:call) ? filter.call(record) :
        filter.is_a?(Array) ? record.send(*filter) : record.send(filter)
    end

    def inspect
      result = "<#{self.class.name}"
      result << " @name=#{@name.inspect}" if @name
      result << " @success_key=#{@success_key.inspect}" if @success_key
      result << " @failure_key=#{@failure_key.inspect}" if @failure_key
      result << " @lock=#{@lock.inspect}" if @lock
      result << " @if=#{@if.inspect}" if @if
        result << " @unless=#{@unless.inspect}" if @unless
        result << '>'
    end

    module Executable
      attr_accessor :action

      def options        ; @options ||= {} ; end
      def options=(value); @options = value; end

      def success_key; action.success_key if action; end
      def failure_key; action.failure_key if action; end
    end

  end
  
end
