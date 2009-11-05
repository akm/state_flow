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
      transaction_with_recovering do
        flow_or_named_event.process(self)
        save_record_if_need
      end
      if options[:keep_process]
        last_current_key = current_attr_key
        while true
          @mark_proceeding = false
          transaction_with_recovering do
            flow.process(self)
            save_record_if_need if @mark_proceeding
          end
          break unless @mark_proceeding
          break if last_current_key == current_attr_key
          last_current_key = current_attr_key
        end
      end
      self
    end
    
    private
    def transaction_with_recovering(&block)
      begin
        flow.klass.transaction(&block)
      rescue ::StateFlow::RecoverableException => exception
        handler = exception.recover_handler
        log_with_stack_trace(:info, "RECOVERING START", :backtrace => true, :exception => exception, :recover_handler => handler)
        start_force_recovering
        begin
          transaction_with_recovering do
            handler.process(self)
            save_record_if_need
          end
          log_with_stack_trace(:info, "RECOVERED", :backtrace => false, :exception => exception, :recover_handler => handler)
        rescue Exception => exception
          exceptions << exception
          trace(exception)
          log_with_stack_trace(:warn, "RECOVERING FAILURE!!!!!", :backtrace => true, :exception => exception, :recover_handler => handler)
          raise
        end
      end
    end
    

    public
    
    def mark_proceeding
      @mark_proceeding = true
    end

    def trace(object)
      ActiveRecord::Base.logger.debug(object.inspect)
      stack_trace << object
    end

    def stack_trace
      @stack_trace ||= []
    end

    def stack_trace_inspects
      stack_trace.map{|st| st.inspect}
    end

    def start_force_recovering ; @force_recovering = true ; end
    def finish_force_recovering; @force_recovering = false; end
    def force_recovering?; @force_recovering; end

    def with_force_recovering(target = nil, *recovering_method_and_args)
      return yield unless force_recovering?
      begin
        return yield
      rescue Exception => exception
        log_with_stack_trace(:warn, "IGNORE EXCEPTION IN RECOVERING", 
            :exception => exception, :backtrace => true)
        if recovering_method_and_args.empty?
          return
        else
          return target.send(*recovering_method_and_args)
        end
      end
    end


    def log_with_stack_trace(level, *messages)
      options = messages.extract_options!
      exception = options.delete(:exception)
      backtrace = options.delete(:backtrace)
      result = "#{messages.shift}"
      result << "\n  exception: #{exception.inspect}" if exception
      messages.each do |msg|
        result << "\n  #{msg}"
      end
      options.each do |key, value|
        result << "\n  #{key.inspect}: #{value.inspect}"
      end
      if exception && backtrace
        result << "\n  exception.backtrace:\n    " << exception.backtrace.join("\n    ")
      end
      result << "\n  context.stack_trace:\n    " << stack_trace_inspects.reverse.join("\n    ")
      ActiveRecord::Base.logger.send(level, result)
    end

    class Manipulation
      attr_reader :target, :method, :args, :block
      attr_reader :trace, :result
      attr_reader :context
      def initialize(context, target, method, *args, &block)
        @context = context
        @target, @method, @args, @block = target, method, args, block
        @trace = caller(3)
      end

      def execute
        begin
          return @result = @target.send(@method, *@args, &@block)
        rescue Exception
          raise unless @context.force_recovering?
        end
      end

      def inspect
        args_part = @args.inspect.gsub(/^\[|\]$/, '')
        if !args_part.nil? && !args_part.empty?
          args_part = "(#{args_part})"
        end
        "#{@target.class.name}##{@method}#{args_part}#{@block ? " with block" : nil}"
      end
    end

    def save_record_if_need
      return unless options[:save]
      manipulation = Manipulation.new(self, record, options[:save])
      trace(manipulation)
      manipulation.execute
    end

    def record_send(*args, &block)
      manipulation = Manipulation.new(self, record, *args, &block)
      trace(manipulation)
      manipulation.execute
    end

    def record_reload_if_possible
      return if record.new_record?
      manipulation = Manipulation.new(self, record, :reload)
      trace(manipulation)
      manipulation.execute 
    end

    def transaction_rollback
      manipulation = Manipulation.new(self, record.class.connection, :rollback_db_transaction)
      trace(manipulation)
      manipulation.execute
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
