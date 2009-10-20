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
          :attr_key_name => "#{selectable_attr}_key".to_sym
        }.update(options || {})
        flow = Base.new(self, selectable_attr, options[:attr_key_name])
        flow.instance_eval(&block)
        @state_flows ||= []
        @state_flows << flow
        flow
      end
    end
    
    attr_reader :klass, :attr_name, :attr_key_name, :status_keys
    attr_reader :entries
    def initialize(klass, attr_name, attr_key_name)
      @klass, @attr_name, @attr_key_name = klass, attr_name, attr_key_name
      @status_keys = klass.send(@attr_key_name.to_s.pluralize).map{|s| s.to_sym}
      @entries = []
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
      result = Entry.new(key)
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
      action = Action.new
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
      NamedAction.new(name)
    end

    def event(name)
      Event.new(name)
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
      attr_accessor :success_key
      attr_accessor :failure_key
      attr_accessor :lock
    end
    
    class NamedAction < Action
      attr_reader :name
      def initialize(name)
        @name = name.to_s.to_sym
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
      attr_reader :name

      def initialize(name)
        @name = name.to_s.to_sym
      end
    end

    class Entry
      include ActionExecutable
      attr_reader :key

      def initialize(key)
        @key = key.to_s.to_sym
      end
      
      def events
        @events ||= [];
      end

      def event_for(name)
        events.detect{|event| event.name == name}
      end

    end
    
    
    
  end
  
end
