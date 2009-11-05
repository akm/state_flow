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
      prepare_exceptions
      exceptions.any?{|klass| exception.is_a?(klass)}
    end

    def process(context)
      context.recovered_exceptions << context.exceptions.last if recovering
      context.record_reload_if_possible # rollbackよりもreloadが先じゃないとネストしたtransactionでおかしい場合がある？
      context.transaction_rollback if rolling_back
      super
    end

    private
    def prepare_exceptions
      return if exceptions.all?{|ex| ex.is_a?(Class)}
      @exceptions = exceptions.map do |ex|
        ex.is_a?(Class) ? ex : ex.to_s.constantize
      end
    end
  end

end
