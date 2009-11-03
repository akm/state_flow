# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class ExceptionHandler < Event
    attr_reader :exceptions
    attr_reader :recovering, :rolling_back, :logging_error
    
    def initialize(origin, *exceptions, &block)
      options = exceptions.extract_options!
      @exceptions = exceptions
      super(origin, &block)
      @recovering = options[:recovering] || false
      @rolling_back = options[:rolling_back] || options[:rollback] || false
      @logging_error = options[:logging]
    end
    
    def match?(exception)
      exceptions.any?{|klass| exception.is_a?(klass)}
    end

    def process(context)
      ActiveRecord::Base.logger.debug(self.inspect)
      context.transaction_rollback if rolling_back
      context.record_reload_if_possible
      super
    end

  end

end
