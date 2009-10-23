module StateFlow
  class Log < ActiveRecord::Base
    set_table_name 'state_flow_logs'
    
    belongs_to :target, :polymorphic => true

    class << self
      def fatal(message, options = nil); write(message, :fatal, options); end
      def error(message, options = nil); write(message, :error, options); end
      def warn (message, options = nil); write(message, :warn , options); end
      def info (message, options = nil); write(message, :info , options); end
      def debug(message, options = nil); write(message, :debug, options); end

      private
      def write(message, level, options = nil)
        log = self.new(options || {})
        log.level = level.to_s
        log.descriptions = message.is_a?(Exception) ? format_exception(message) : message
        unless log.save
          logger.error(log.inspect)
        end
      end
      
      def format_exception(exception)
        '%s\n  %s' % [exception.to_s, exception.backtrace.join("\n  ")]
      end

    end
  end
end
