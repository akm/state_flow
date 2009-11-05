module StateFlow
  class RecoverableException < Exception
    attr_reader :recover_handler, :original
    def initialize(recover_handler, original = nil)
      @recover_handler = recover_handler
      @original = original
      super("#{original ? original.inspect + ' ' : nil}RECOVERABLE by " << recover_handler.inspect)
    end
    
  end

end
