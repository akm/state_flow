# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class Base
    
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
        module_eval(<<-EOS, __FILE__, __LINE__)
          def process_#{selectable_attr}(context_or_options = nil)
            flow = self.class.state_flow_for(:#{selectable_attr})
            context = flow.prepare_context(self, context_or_options)
            flow.process(context)
            context.save_record_if_need
            context
          end
        EOS
        NamedEvent.build_event_methods(flow)
        flow
      end
          
      def process_state(selectable_attr, *keys, &block)
        options = {
          :transactional => false, # :each, # :all
        }.update(keys.extract_options!)
        options[:transactional] = :each if options[:transactional] == true
        state_flow = state_flow_for(selectable_attr)
        raise ArgumentError, "state_flow not found: #{selectable_attr.inspect}" unless state_flow
        transaction_if_need(options[:transactional] == :all) do
          keys.each do |key|
            entry = state_flow[key]
            raise ArgumentError, "entry not found: #{key.inspect}" unless entry
            transaction_if_need(options[:transactional] == :each) do
              entry.process(&block)
            end
          end
        end
      end
      
      def transaction_if_need(with_transaction, &block)
        if with_transaction
          self.transaction(&block)
        else
          yield
        end
      end
    end

    attr_reader :klass, :attr_name, :attr_key_name, :status_keys
    def initialize(klass, attr_name, attr_key_name)
      @klass, @attr_name, @attr_key_name = klass, attr_name, attr_key_name
      @status_keys = klass.send(@attr_key_name.to_s.pluralize).map{|s| s.to_sym}
    end

    def state_cd_by_key(key)
      @state_cd_by_key_method_name ||= "#{klass.enum_base_name(attr_name)}_id_by_key"
      klass.send(@state_cd_by_key_method_name, key)
    end

    def state(name, &block)
      result = State.new(self, name, &block)
      states << result
      result
    end
    alias_method :group, :state
    alias_method :state_group, :state

    def states
      @states ||= []
    end

    def all_states
      unless @all_states
        @all_states = states.map{|state| state.descendants}.flatten.inject({}) do |dest, state|
          dest[state.name] = state
          dest
        end
      end
      @all_states
    end

    def concrete_states
      unless @concrete_states
        @concrete_states = {}
        all_states.each do |name, state| 
          @concrete_states[state.name] = state if state.concrete?
        end
      end
      @concrete_states
    end

    def origin(value = nil)
      if value
        @origin_name = value
      else
        @origin ||= all_states[@origin_name]
      end
    end

    def prepare_context(record, context_or_options = nil)
      context_or_options.is_a?(StateFlow::Context) ?
        context_or_options :
        StateFlow::Context.new(record, context_or_options)
    end

    def process(context)
      current_key = context.record_send(attr_key_name)
      state = concrete_states[current_key]
      klass.transaction do
        state.process(context)
      end
      context
    end

    def process_with_log(record, success_key, failure_key)
      origin_state = record.send(attr_name)
      origin_state_key = record.send(attr_key_name)
      begin
        yield(record) if block_given?
        # success_keyが指定されない場合、その変更はアクションとして指定されたメソッドに依存します。
        if success_key 
          record.send("#{attr_key_name}=", success_key)
          record.save!
        end
      rescue Exception => error
        log_attrs = {
          :target => record,
          :origin_state => origin_state,
          :origin_state_key => origin_state_key ? origin_state_key.to_s : nil,
          :dest_state => self.state_cd_by_key(success_key),
          :dest_state_key => success_key ? success_key.to_s : nil
        }
        StateFlow::Log.error(error, log_attrs)
        if failure_key
          retry_count = 0
          begin
            record.send("#{attr_key_name}=", failure_key)
            record.save!
          rescue Exception => fatal_error
            if retry_count == 0
              retry_count += 1
              record.attributes = record.class.find(record.id).attributes
              retry
            end
            StateFlow::Log.fatal(fatal_error, log_attrs)
            raise fatal_error
          end
        end
        raise error
      end
    end

    def inspect
      result = "<#{self.class.name} @attr_name=#{@attr_name.inspect} @attr_key_name=#{@attr_key_name.inspect}"
      result << " @klass=\"#{@klass.name}\""
      result << " @entries=#{@entries.inspect}"
      result << '>'
    end

  end

end
