# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  module Builder
    module ClientClassMethods
      def state_flow_for(selectable_attr)
        return nil unless @state_flows
        @state_flows.detect{|flow| flow.attr_name == selectable_attr}
      end

      def state_flow(selectable_attr, options = nil, &block)
        options = {
          :attr_key_name => "#{self.enum_base_name(selectable_attr)}_key".to_sym
        }.update(options || {})
        flow = Base.new(self, selectable_attr, options[:attr_key_name])
        flow.instance_eval(&block)
        @state_flows ||= []
        @state_flows << flow
        flow
      end
    end
  
  end

end
