# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class Element
    include ElementVisitable

    attr_reader :origin
    attr_reader :destination
    def initialize(origin, &block)
      @origin = origin
      instance_eval(&block) if block
    end

    def to(destination)
      @destination = destination
    end

    def flow
      @flow || origin.flow
    end

    def state
      origin.is_a?(State) ? origin : origin.state
    end

    def update_to_destination(context)
      return unless destination
      context.mark_proceeding
      context.record_send("#{flow.attr_key_name}=", destination)
    end

    class << self
      def uninspected_var(*vars)
        @@uninspected_var_hash ||= {}
        @@uninspected_var_hash[self] ||= []
        @@uninspected_var_hash[self].concat(vars.map{|v| v.to_s.sub(/^([^@])/){"@#{$1}"}})
      end

      def uninspected_vars
        @uninspected_vars ||= @@uninspected_var_hash.nil? ? %w(@flow @origin) :
          self.ancestors.map{|klass| @@uninspected_var_hash[klass] || []}.flatten
      end
    end
    self.uninspected_var :flow, :origin, :events, :guards, :action
 
    def inspect
      vars = (instance_variables - self.class.uninspected_vars).map do |name|
        "#{name}=#{instance_variable_get(name).inspect}"
      end
      # vars = []
      vars.unshift("%s:%#x" % [self.class.name, self.object_id])
      "#<#{vars.join(' ')}>"
    end
    
  end

end
