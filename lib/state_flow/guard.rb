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
      update_to_destination(record)
    end

  end

end
