# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  module ExceptionHandlerClient
    def exception_handlers
      events.select{|ev| ev.is_a?(ExceptionHandler)}
    end

    def exception_handling(context)
      if context.force_recovering?
        begin
          return yield
        rescue Exception => err
          context.log_with_stack_trace(:warn, "IGNORED ERROR by force_recovering", 
            :exception => err, :backtrace => true)
          # ignore exception
          update_to_destination(context)
          return
        end
      end
      
      handlers = exception_handlers
      return yield if handlers.empty?
      ActiveRecord::Base.logger.debug("---- exception_handling BEGIN by #{self.inspect}")
      begin
        return yield
        ActiveRecord::Base.logger.debug("---- exception_handling END by #{self.inspect}")
      rescue Exception => exception
        context.exceptions << exception
        context.trace(exception)
        recover_handler = nil
        handlers.each do |handler|
          next unless handler.match?(exception)
          recover_handler = handler
          begin
            unless handler.raise_error_in_handling
              context.start_force_recovering
              context.log_with_stack_trace(:warn, "FORCE RECOVERING START",
                :exception => err, :backtrace => true, 
                :recover_handler => recover_handler)
            end
            handler.process(context)
          rescue Exception => err
            context.exceptions << err
            context.trace(err)
            context.log_with_stack_trace(:warn, "RECOVERING FAILURE!!!!!", 
              :exception => err, :backtrace => true, 
              :recover_handler => recover_handler)
            raise err
          end
          break
        end
        if context.recovered?(exception)
          context.log_with_stack_trace(:info, "RECOVERED", 
            :exception => exception, :backtrace => false, 
            :recover_handler => recover_handler)
        else
          context.log_with_stack_trace(:error, "NOT RECOVERED", 
            :exception => exception, :backtrace => true, 
            :exception_handlers => handlers, :recover_handler => recover_handler)
          raise exception
        end
      end
    end

  end


end
