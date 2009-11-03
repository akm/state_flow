require 'state_flow'
module StateFlow

  class Guard < Entry
    include EventClient
    include ActionClient

    def match?(record)
      true
    end

    def process(record)
      action.process(record) if action
    end

  end

end
