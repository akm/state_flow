# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  module ExceptionHandlerClient
    def exception_handling(context)
      begin
        yield
      rescue Exception => exception
        context.exceptions << exception
        context.trace(exception)
        handlers = events.select{|ev| ev.is_a?(ExceptionHandler)}
        handlers.each do |handler|
          next unless handler.match?(exception)
          handler.process(context)
          break
        end
        raise exception unless context.recovered?(exception)
      end
    end

  end


end
