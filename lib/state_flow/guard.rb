require 'state_flow'
module StateFlow

  class Guard < Element
    include EventClient
    include ActionClient

    def match?(context)
      true
    end

    def process(context)
      exception_handling(context) do
        action.process(context) if action
        update_to_destination(context)
      end
    end

  end

end
