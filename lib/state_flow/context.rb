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
    
  end

end
