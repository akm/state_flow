module StateFlow

  class Context
    
    attr_reader :record, :options
    def initialize(record, options = nil)
      @record = record
      @options = {
        :save => false,
        :save! => false,
      }.update(options || {})
    end

    def save_record_if_need
      if options[:save!]
        record.save!
      elsif options[:save]
        record.save
      end
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

  end

end
