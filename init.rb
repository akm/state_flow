require 'state_flow'

ActiveRecord::Base.module_eval do
  include StateFlow
end
