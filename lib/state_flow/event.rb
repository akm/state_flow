# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class Event < Entry
    include GuardClient
    include ActionClient
  end

end
