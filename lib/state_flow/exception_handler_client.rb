# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  module ExceptionHandlerClient
    def exception_handlers
      events.select{|ev| ev.is_a?(ExceptionHandler)}
    end

    def exception_handling(context)
      handlers = exception_handlers
      return yield if handlers.empty?
      ActiveRecord::Base.logger.debug("---- exception_handling BEGIN by #{self.inspect}")
      begin
        yield
        ActiveRecord::Base.logger.debug("---- exception_handling END by #{self.inspect}")
      rescue Exception => exception
        ActiveRecord::Base.logger.debug("---- #{self.inspect} handliing exception: #{exception.inspect}")
        context.exceptions << exception
        context.trace(exception)
        recover_handler = nil
        handlers.each do |handler|
          next unless handler.match?(exception)
          recover_handler = handler
          begin
            handler.process(context)
          rescue Exception => err
            ActiveRecord::Base.logger.debug("RECOVERING FAILURE!!!!! #{err.inspect} by #{handler.inspect}\n  " <<
              context.stack_trace.join("\n  ") << "\n  " <<
              err.backtrace.join("\n  "))
            raise err
          end
          break
        end
        if context.recovered?(exception)
          ActiveRecord::Base.logger.debug("RECOVERED ----- #{exception.inspect} by #{recover_handler.inspect} for #{recover_handler.exceptions.inspect}")
        else
          ActiveRecord::Base.logger.debug(
            "NOT RECOVERED - #{exception.inspect}\n  " <<
            (recover_handler ? "tried by #{recover_handler.inspect}\n  " : "" ) <<
            "exception_handlers: #{handlers.inspect}\n  " <<
            context.stack_trace.map{|st| st.inspect}.join("\n  ") << "\n  " <<
            exception.backtrace.join("\n  "))
          raise exception
        end
      end
    end

  end


end
