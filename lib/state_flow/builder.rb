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
        flow.setup_events
        @state_flows ||= []
        @state_flows << flow
        flow
      end
    end

    def new_entry(key)
      @entry_hash = nil
      result = Entry.new(self, key)
      entries << result
      result
    end

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

    def action(name)
      NamedAction.new(self, name)
    end

    def event(name)
      Event.new(self, name)
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
      action.failure_key = options.delete(:failure)
      action.lock = options.delete(:lock)
      action.if = options.delete(:if)
      action.unless = options.delete(:unless)
      action
    end


    def build_events(entry, event_hash, options)
      event_hash.each do |event, value|
        build_entry(event, value, options)
        entry.events << event
      end
    end

    COMMON_OPTION_NAMES = [:lock, :if, :unless, :failure]

    def extract_common_options(hash)
      COMMON_OPTION_NAMES.inject({}) do |dest, name|
        value = hash.delete(name)
        dest[name] = value if value
        dest
      end
    end

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
    
  end

end
