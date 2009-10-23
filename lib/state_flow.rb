module StateFlow
  autoload :Base, 'state_flow/base'
  autoload :Log, 'state_flow/log'
  
  # autoload :ActiveRecord, 'state_flow/active_record'
  
  def self.included(mod)
    mod.module_eval do
      extend ::StateFlow::Base::ClassMethods
      # include ::StateFlow::ActiveRecord if mod.ancestors.map{|m| m.name}.include?('ActiveRecord::Base')
    end
  end
  
end
