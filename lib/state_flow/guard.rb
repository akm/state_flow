require 'state_flow'
module StateFlow

  class Guard < Entry
    include EventClient
    include ActionClient

    def match?(context)
      true
    end

    def process(context)
      exception_handlering(context) do
        action.process(context) if action
        update_to_destination(context)
      end
    end

  end

end
