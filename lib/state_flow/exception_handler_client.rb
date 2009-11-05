# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  module ExceptionHandlerClient
    # 例外ハンドラの配列を返します。
    # StateFlow::Stateはこれを上書きして親のハンドラも含めて返します。
    def exception_handlers
      events.select{|ev| ev.is_a?(ExceptionHandler)}
    end

    def exception_handling(context)
      if context.force_recovering?
        begin
          return yield
        rescue Exception => exception
          context.log_with_stack_trace(:warn, "IGNORE EXCEPTION IN RECOVERING", 
            :exception => exception, :backtrace => true)
          return retry_in_recovering(context) if respond_to?(:retry_in_recovering)
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
        if recover_handler = handlers.detect{|handler| handler.match?(exception)}
          raise ::StateFlow::RecoverableException.new(recover_handler, exception)
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
