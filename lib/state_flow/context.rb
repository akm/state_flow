module StateFlow

  class Context
    
    attr_reader :flow, :record, :options
    
    def initialize(flow, record, options = nil)
      @flow, @record = flow, record
      @options = {
        :save => :save!,
      }.update(options || {})
    end

    def process(flow_or_named_event = flow)
      flow.klass.transaction do
        flow_or_named_event.process(self)
        save_record_if_need
      end
      self
    end


    def save_record_if_need
      return unless options[:save]
      record.send(options[:save])
    end

    def record_send(*args, &block)
      record.send(*args, &block)
    end

    def record_reload_if_possible
      record.reload unless record.new_record?
    end

    def transaction_rollback
      record.class.connection.rollback_db_transaction
    end
    
    def exceptions
      @exceptions ||= []
    end

    def recovered_exceptions
      @recovered_exceptions ||= []
    end

    def recovered?(exception)
      recovered_exceptions.include?(exception)
    end

  end

end
