require 'state_flow'
module StateFlow

  class Guard < Entry
    include EventClient
    include ActionClient

  end

end

