# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  class Base
    module ClassMethods
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
        flow.setup_events
        @state_flows ||= []
        @state_flows << flow
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
    attr_reader :entries
    def initialize(klass, attr_name, attr_key_name)
      @klass, @attr_name, @attr_key_name = klass, attr_name, attr_key_name
      @status_keys = klass.send(@attr_key_name.to_s.pluralize).map{|s| s.to_sym}
      @entries = []
    end

    def state_cd_by_key(key)
      @state_cd_by_key_method_name ||= "#{klass.enum_base_name(attr_name)}_id_by_key"
      klass.send(@state_cd_by_key_method_name, key)
    end
    
    def entry_for(key)
      unless @entry_hash
        @entry_hash = entries.inject({}) do |dest, entry|
          dest[entry.key] = entry
          dest
        end
      end
      @entry_hash[key]
    end
    alias_method :[], :entry_for

    def new_entry(key)
      @entry_hash = nil
      result = Entry.new(self, key)
      entries << result
      result
    end

    COMMON_OPTION_NAMES = [:lock, :if, :unless]

    def state(*args)
      raise_invalid_state_argument if args.length > 2
      if args.length == 2
        # 引数が２個ならできるだけ一つのHashにまとめます。
        case args.first
        when Hash then 
          return state(args.first.update(args.last))
        when Symbol, String
          return state({args.first => nil}.update(args.last))
        else
          raise_invalid_state_argument
        end
      end
      # 引数が一つだけになってます
      arg = args.first
      case arg
      when Symbol, String
        return state({args.first => nil})
      when Hash then
        # through
      else
        raise_invalid_state_argument
      end
      # 引数がHash一つだけの場合
      base_options = extract_common_options(arg)
      arg.each do |key, value|
        entry = new_entry(key)
        build_entry(entry, value, base_options)
      end
    end

    def setup_events
      event_defs = {}
      entries.each do |entry|
        origin_key = entry.key
        entry.events.each do |event|
          event_trans = event_defs[event.name] ||= {}
          event_trans[origin_key] = [event.success_key, event.failure_key]
        end
      end
      event_defs.each do |event_name, trans|
        method_def = <<-"EOS"
          def #{event_name}
            @state_flow ||= self.class.state_flow_for(:#{attr_name})
            @#{event_name}_transitions ||= #{trans.inspect}
            @state_flow.process_with_log(self, 
              *@#{event_name}_transitions[#{attr_key_name}])
          end
        EOS
        if klass.instance_methods.include?(event_name)
          klass.logger.warn("state_flow plugin was going to define #{event_name} but didn't do it because #{event_name} does exist.")
        else
          klass.module_eval(method_def, __FILE__, __LINE__)
        end
      end
    end

    def process_with_log(record, success_key, failure_key)
      origin_state = record.send(attr_name)
      origin_state_key = record.send(attr_key_name)
      begin
        yield(record) if block_given?
        record.send("#{attr_key_name}=", success_key)
        record.save!
      rescue Exception
        StateFlow::Log.error($!, 
          :target => record,
          :origin_state => origin_state,
          :origin_state_key => origin_state_key.to_s,
          :dest_state => self.state_cd_by_key(success_key),
          :dest_state_key => success_key.to_s
          )
        if failure_key
          begin
            record.send("#{attr_key_name}=", failure_key)
            record.save!
          rescue Exception
            StateFlow::Log.fatal($!,
              :target => record,
              :origin_state => origin_state,
              :origin_state_key => origin_state_key.to_s,
              :dest_state => flow.state_cd_by_key(success_key),
              :dest_state_key => success_key.to_s
              )
            raise
          end
        end
        raise
      end
    end

    private
    
    def build_entry(entry, options_or_success_key, base_options)
      if options_or_success_key.nil?
        return null_action_entry(entry, base_options)
      end
      case options_or_success_key
      when String, Symbol then
        return null_action_entry(entry, base_options, options_or_success_key.to_sym)
      when Action then
        entry.action = setup_action(options_or_success_key, base_options)
        return entry
      when Hash then
        options = options_or_success_key
        prior_options = extract_common_options(options)
        options_keys = options.keys
        if options_keys.all?{|key| key.is_a?(Action)}
          build_action(entry, options, base_options.merge(prior_options))
        elsif options_keys.all?{|key| key.is_a?(Event)}
          raise_invalid_state_argument unless entry.is_a?(Entry)
          build_events(entry, options, base_options.merge(prior_options))
        else
          raise_invalid_state_argument
        end
      when Array then
        options_or_success_key.each do |options|
          each_base_options = base_options.merge(extract_common_options(options))
          build_entry(entry, options, each_base_options)
        end
      else
        raise_invalid_state_argument
      end
    end

    def null_action_entry(entry, options, success_key = nil)
      action = Action.new(self)
      options = options.dup
      entry.action = setup_action(action, options, success_key)
      entry.options = options
      entry
    end

    def build_action(entry, action_hash, options)
      raise_invalid_state_argument unless action_hash.length == 1
      options = options.dup
      entry.action = setup_action(action_hash.keys.first, options, action_hash.values.first)
      entry.options = options
    end

    def setup_action(action, options, success_key = nil)
      action.success_key = success_key.to_sym if success_key
      action.lock = options.delete(:lock)
      action
    end


    def build_events(entry, event_hash, options)
      event_hash.each do |event, value|
        build_entry(event, value, options)
        entry.events << event
      end
    end

    public

    def action(name)
      NamedAction.new(self, name)
    end

    def event(name)
      Event.new(self, name)
    end

    
    private

    def raise_invalid_state_argument
      raise ArgumentError, state_argument_pattern
    end

    def state_argument_pattern
      descriptions = <<-"EOS"
        state arguments pattern:
          * state :<state_name>
          * state :<state_name> => :<new_state_name>
          * state :<state_name> => action(:<method_name>)
          * state :<state_name> => { action(:<method_name>) => :<new_state_name>}
          * state :<state_name> => { event(:<event_name1>) => :<new_state_name>, event(:<event_name2>) => :<new_state_name>}
          * state :<state_name> => { event(:<event_name1>) => { action(:<method_name1>) => :<new_state_name>}, event(:<event_name2>) => {action(:<method_name1>) => :<new_state_name>} }
        And you can append :lock, :if, :unless option in Hash
      EOS
      descriptions.split(/$/).map{|s| s.sub(/^\s{8}/, '')}.join("\n")
    end

    def extract_common_options(hash)
      COMMON_OPTION_NAMES.inject({}) do |dest, name|
        value = hash.delete(name)
        dest[name] = value if value
        dest
      end
    end

    
    class Action
      attr_reader :flow
      attr_accessor :success_key
      attr_accessor :failure_key
      attr_accessor :lock

      def initialize(flow)
        @flow = flow
        @record_key_on_thread = "#{self.class.name}_#{self.object_id}_record"
      end

      def record
        Thread.current[@record_key_on_thread]
      end

      def record=(value)
        Thread.current[@record_key_on_thread] = value
      end

      
      def proceed
        flow.process_with_log(self.record, success_key, failure_key)
      end

      def process(record)
        self.record = record
        begin
          block_given? ? yield(self) : proceed
        ensure
          self.record = nil
        end
      end
    end
    
    class NamedAction < Action
      attr_reader :name
      def initialize(flow, name)
        super(flow)
        @name = name.to_s.to_sym
      end

      def proceed
        self.record.send(name)
        super
      end
    end
    
    module ActionExecutable
      attr_accessor :action

      def options        ; @options ||= {} ; end
      def options=(value); @options = value; end

      def success_key; action.success_key if action; end
      def failure_key; action.failure_key if action; end
    end
    
    class Event
      include ActionExecutable
      attr_reader :flow, :name

      def initialize(flow, name)
        @flow = flow
        @name = name.to_s.to_sym
      end
    end

    class Entry
      include ActionExecutable
      attr_reader :flow, :key

      def initialize(flow, key)
        @flow = flow
        @key = key.to_s.to_sym
      end
      
      def events
        @events ||= [];
      end

      def event_for(name)
        events.detect{|event| event.name == name}
      end

      def process(&block)
        value = flow.state_cd_by_key(key)
        if record = flow.klass.find(:first, :order => "id asc",
            :lock => action ? action.lock : false,
            :conditions => ["#{flow.attr_name} = ?", value])
          action.process(record, &block) if action
        end
      end
    end
    
  end
  
end
