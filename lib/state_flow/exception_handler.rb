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
      @logging_error = options[:logging_error] || false
    end
    
    def match?(exception)
      exceptions.any?{|klass| exception.is_a?(klass)}
    end

    def process(record)
      record.reload unless record.new_record?
      # record.class.connection.rollback_to_savepoint if rolling_back
      record.class.connection.rollback_db_transaction if rolling_back
      super
    end

  end

end
