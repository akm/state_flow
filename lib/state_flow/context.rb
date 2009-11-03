module StateFlow

  class Context
    
    attr_reader :flow, :record, :options
    
    def initialize(flow, record, options = nil)
      @flow, @record = flow, record
      @options = {
        :save => :save!,
        :keep_process => true
      }.update(options || {})
    end

    def process(flow_or_named_event = flow)
      flow.klass.transaction do
        flow_or_named_event.process(self)
        save_record_if_need
      end
      if options[:keep_process]
        last_current_key = current_attr_key
        while true
          @mark_proceeding = false
          flow.process(self)
          save_record_if_need if @mark_proceeding
          break unless @mark_proceeding
          break if last_current_key == current_attr_key
          last_current_key = current_attr_key
        end
      end
      self
    end

    def mark_proceeding
      @mark_proceeding = true
    end

    def trace(object)
      stack_trace << object
    end

    def stack_trace
      @stack_trace ||= []
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

    def current_attr_key
      record_send(flow.attr_key_name)
    end

  end

end
