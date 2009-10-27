# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), 'spec_helper')
 
describe StateFlow::Base do
  describe "state" do

    before(:each) do
      @target = Class.new do
        include ::SelectableAttr::Base
        extend ::StateFlow::Base::ClassMethods

        selectable_attr(:status) do
          entry '01', :foo, "FOO"
          entry '02', :bar, "BAR"
          entry '03', :baz, "BAZ"
        end
      end
    end
    
    describe "valid arguments" do
      describe "state(:<state_name>)" do
        before(:each) do
          @flow = @target.state_flow(:status) do
            state :foo
            state :bar, :lock => true
          end
        end

        it "inspect" do
          klass_name = 
          @flow.inspect.should == '<StateFlow::Base @attr_name=:status @attr_key_name=:status_key' <<
            " @klass=#{@target.name.inspect}" <<
            ' @entries=[' <<
            '<StateFlow::Entry @key=:foo @action=<StateFlow::Action>>, ' <<
            '<StateFlow::Entry @key=:bar @action=<StateFlow::Action @lock=true>>' <<
            ']>'
        end
        
        it "check" do
          @flow[:foo].key.should == :foo
          @flow[:foo].events.should == []
          @flow[:foo].success_key.should == nil
          @flow[:foo].options.should == {}
          @flow[:bar].key.should == :bar
          @flow[:bar].events.should == []
          @flow[:bar].success_key.should == nil
          @flow[:bar].action.lock.should == true
          @flow[:bar].action.lock.should == true
        end
      end

      describe "state(:<state_name> => nil)" do
        before(:each) do
          @flow = @target.state_flow(:status) do
            state :foo => nil
            state :bar => nil, :lock => true
          end
        end
        
        it "inspect" do
          klass_name = 
          @flow.inspect.should == '<StateFlow::Base @attr_name=:status @attr_key_name=:status_key' <<
            " @klass=#{@target.name.inspect}" <<
            ' @entries=[' <<
            '<StateFlow::Entry @key=:foo @action=<StateFlow::Action>>, ' <<
            '<StateFlow::Entry @key=:bar @action=<StateFlow::Action @lock=true>>' <<
            ']>'
        end
        
        it "check" do
          @flow[:foo].key.should == :foo
          @flow[:foo].events.should == []
          @flow[:foo].success_key.should == nil
          @flow[:foo].options.should == {}
          @flow[:bar].key.should == :bar
          @flow[:bar].events.should == []
          @flow[:bar].success_key.should == nil
          @flow[:bar].action.lock.should == true
        end
      end

      describe "state(:<state_name> => :<new_state_name>) with :if/:unless" do
        before(:each) do
          proc_obj = Proc.new{|record| true} # インスタンス変数に格納するとなぜかうまく動かないんです・・・？
          @proc_inspect = proc_obj.inspect
          @flow = @target.state_flow(:status) do
            state :foo => :bar
            state :bar => :baz, :if => proc_obj
            state({:baz => :foo}, {:unless => :some_method?})
          end
        end
        
        it "inspect" do
          klass_name = 
          @flow.inspect.should == '<StateFlow::Base @attr_name=:status @attr_key_name=:status_key' <<
            " @klass=#{@target.name.inspect}" <<
            ' @entries=[' <<
            '<StateFlow::Entry @key=:foo @action=<StateFlow::Action @success_key=:bar>>, ' <<
            "<StateFlow::Entry @key=:bar @action=<StateFlow::Action @success_key=:baz @if=#{@proc_inspect}>>, " <<
            '<StateFlow::Entry @key=:baz @action=<StateFlow::Action @success_key=:foo @unless=:some_method?>>' <<
            ']>'
        end
        
        it "check" do
          @flow[:foo].key.should == :foo
          @flow[:foo].events.should == []
          @flow[:foo].success_key.should == :bar
          @flow[:foo].options.should == {}
          @flow[:bar].key.should == :bar
          @flow[:bar].events.should == []
          @flow[:bar].success_key.should == :baz
          @flow[:bar].action.if.class.should == Proc 
          @flow[:baz].key.should == :baz
          @flow[:baz].events.should == []
          @flow[:baz].success_key.should == :foo
          @flow[:baz].action.unless.should == :some_method?
        end
      end


      describe "state(:<state_name> => :<new_state_name>)" do
        before(:each) do
          @flow = @target.state_flow(:status) do
            state :foo => :bar
            state :bar => :baz, :lock => true
            state({:baz => :foo}, {:lock => true})
          end
        end
        
        it "inspect" do
          klass_name = 
          @flow.inspect.should == '<StateFlow::Base @attr_name=:status @attr_key_name=:status_key' <<
            " @klass=#{@target.name.inspect}" <<
            ' @entries=[' <<
            '<StateFlow::Entry @key=:foo @action=<StateFlow::Action @success_key=:bar>>, ' <<
            '<StateFlow::Entry @key=:bar @action=<StateFlow::Action @success_key=:baz @lock=true>>, ' <<
            '<StateFlow::Entry @key=:baz @action=<StateFlow::Action @success_key=:foo @lock=true>>' <<
            ']>'
        end
        
        it "check" do
          @flow[:foo].key.should == :foo
          @flow[:foo].events.should == []
          @flow[:foo].success_key.should == :bar
          @flow[:foo].options.should == {}
          @flow[:bar].key.should == :bar
          @flow[:bar].events.should == []
          @flow[:bar].success_key.should == :baz
          @flow[:bar].action.lock.should == true
          @flow[:baz].key.should == :baz
          @flow[:baz].events.should == []
          @flow[:baz].success_key.should == :foo
          @flow[:baz].action.lock.should == true
        end
      end

      describe "state(:<state_name> => :<new_state_name>, :failure => <:failure_state>)" do
        before(:each) do
          @flow = @target.state_flow(:status) do
            state :foo => :bar, :failure => :baz
            state :bar => :baz, :lock => true
            state({:baz => :foo}, {:lock => true})
          end
        end
        
        it "inspect" do
          klass_name = 
          @flow.inspect.should == '<StateFlow::Base @attr_name=:status @attr_key_name=:status_key' <<
            " @klass=#{@target.name.inspect}" <<
            ' @entries=[' <<
            '<StateFlow::Entry @key=:foo @action=<StateFlow::Action @success_key=:bar @failure_key=:baz>>, ' <<
            '<StateFlow::Entry @key=:bar @action=<StateFlow::Action @success_key=:baz @lock=true>>, ' <<
            '<StateFlow::Entry @key=:baz @action=<StateFlow::Action @success_key=:foo @lock=true>>' <<
            ']>'
        end
        
        it "check" do
          @flow[:foo].key.should == :foo
          @flow[:foo].events.should == []
          @flow[:foo].success_key.should == :bar
          @flow[:foo].failure_key.should == :baz
          @flow[:foo].options.should == {}
          @flow[:bar].key.should == :bar
          @flow[:bar].events.should == []
          @flow[:bar].success_key.should == :baz
          @flow[:bar].action.lock.should == true
          @flow[:baz].key.should == :baz
          @flow[:baz].events.should == []
          @flow[:baz].success_key.should == :foo
          @flow[:baz].action.lock.should == true
        end
      end

      describe "state(:<state_name> => action(:<method_name>))" do
        before(:each) do
          @flow = @target.state_flow(:status) do
            state :foo => action(:hoge)
            state :bar => action(:hoge), :lock => true
            state({:baz => action(:hoge)}, {:lock => true})
          end
        end
        
        it "inspect" do
          klass_name = 
          @flow.inspect.should == '<StateFlow::Base @attr_name=:status @attr_key_name=:status_key' <<
            " @klass=#{@target.name.inspect}" <<
            ' @entries=[' <<
            '<StateFlow::Entry @key=:foo @action=<StateFlow::NamedAction @name=:hoge>>, ' <<
            '<StateFlow::Entry @key=:bar @action=<StateFlow::NamedAction @name=:hoge @lock=true>>, ' <<
            '<StateFlow::Entry @key=:baz @action=<StateFlow::NamedAction @name=:hoge @lock=true>>' <<
            ']>'
        end
        
        it "check" do
          @flow[:foo].key.should == :foo
          @flow[:foo].events.should == []
          @flow[:foo].action.name.should == :hoge
          @flow[:foo].success_key.should == nil
          @flow[:foo].options.should == {}
          @flow[:bar].key.should == :bar
          @flow[:bar].events.should == []
          @flow[:bar].action.name.should == :hoge
          @flow[:bar].success_key.should == nil
          @flow[:bar].action.lock.should == true
          @flow[:baz].key.should == :baz
          @flow[:baz].events.should == []
          @flow[:baz].action.name.should == :hoge
          @flow[:baz].success_key.should == nil
          @flow[:baz].action.lock.should == true
        end
      end

      describe "state(:<state_name> => {action(:<method_name>) => :<new_state_name>})" do
        before(:each) do
          @flow = @target.state_flow(:status) do
            begin
              state :foo => {action(:hoge) => :bar}
              state :bar => {action(:hoge) => :baz}, :lock => true
              state :baz => {action(:hoge) => :foo, :lock => true}
            rescue Exception
              puts $!.backtrace.join("\n  ")
              raise
            end
          end
        end
        
        it "inspect" do
          klass_name = 
          @flow.inspect.should == '<StateFlow::Base @attr_name=:status @attr_key_name=:status_key' <<
            " @klass=#{@target.name.inspect}" <<
            ' @entries=[' <<
            '<StateFlow::Entry @key=:foo @action=<StateFlow::NamedAction @name=:hoge @success_key=:bar>>, ' <<
            '<StateFlow::Entry @key=:bar @action=<StateFlow::NamedAction @name=:hoge @success_key=:baz @lock=true>>, ' <<
            '<StateFlow::Entry @key=:baz @action=<StateFlow::NamedAction @name=:hoge @success_key=:foo @lock=true>>' <<
            ']>'
        end
        
        it "check" do
          @flow[:foo].key.should == :foo
          @flow[:foo].events.should == []
          @flow[:foo].action.name.should == :hoge
          @flow[:foo].action.success_key.should == :bar
          @flow[:foo].success_key.should == :bar
          @flow[:foo].options.should == {}
          @flow[:bar].key.should == :bar
          @flow[:bar].events.should == []
          @flow[:bar].action.name.should == :hoge
          @flow[:bar].action.success_key.should == :baz
          @flow[:bar].success_key.should == :baz
          @flow[:bar].action.lock.should == true
          @flow[:baz].key.should == :baz
          @flow[:baz].events.should == []
          @flow[:baz].action.name.should == :hoge
          @flow[:baz].action.success_key.should == :foo
          @flow[:baz].success_key.should == :foo
          @flow[:baz].action.lock.should == true
        end
      end

      describe "with_events" do
        def check_flow_with_event
          @flow[:foo].key.should == :foo
          @flow[:foo].events.should_not == []
          @flow[:foo].event_for(:event1).should_not be_nil
          @flow[:foo].event_for(:event1).success_key.should == :bar
          @flow[:foo].event_for(:event2).success_key.should == :baz
          @flow[:foo].action.should be_nil
          @flow[:foo].success_key.should == nil
          @flow[:foo].options.should == {}
          @flow[:bar].key.should == :bar
          @flow[:bar].event_for(:event1).should_not be_nil
          @flow[:bar].event_for(:event1).success_key.should == :baz
          @flow[:bar].event_for(:event2).success_key.should == :foo
          @flow[:bar].event_for(:event1).action.lock.should == true
          @flow[:bar].event_for(:event2).action.lock.should == true
          @flow[:bar].action.should be_nil
          @flow[:bar].success_key.should == nil
          @flow[:baz].key.should == :baz
          @flow[:baz].event_for(:event1).should_not be_nil
          @flow[:baz].event_for(:event1).success_key.should == :foo
          @flow[:baz].event_for(:event2).success_key.should == :bar
          @flow[:baz].event_for(:event1).action.lock.should == true
          @flow[:baz].event_for(:event2).action.lock.should == true
          @flow[:baz].action.should be_nil
          @flow[:baz].success_key.should == nil
        end

        def check_inspect_with_event
          klass_name = @target.name
          @flow.inspect.should == '<StateFlow::Base @attr_name=:status @attr_key_name=:status_key' <<
            " @klass=#{@target.name.inspect}" <<
            ' @entries=[' <<
              '<StateFlow::Entry @key=:foo @events=[' << 
                '<StateFlow::Event @name=:event1 @action=<StateFlow::Action @success_key=:bar>>, ' << 
                '<StateFlow::Event @name=:event2 @action=<StateFlow::Action @success_key=:baz>>' << 
              ']>, ' <<
              '<StateFlow::Entry @key=:bar @events=[' << 
                '<StateFlow::Event @name=:event1 @action=<StateFlow::Action @success_key=:baz @lock=true>>, ' << 
                '<StateFlow::Event @name=:event2 @action=<StateFlow::Action @success_key=:foo @lock=true>>' << 
              ']>, ' <<
              '<StateFlow::Entry @key=:baz @events=[' << 
                '<StateFlow::Event @name=:event1 @action=<StateFlow::Action @success_key=:foo @lock=true>>, ' << 
                '<StateFlow::Event @name=:event2 @action=<StateFlow::Action @success_key=:bar @lock=true>>' << 
              ']>' <<
            ']>'
        end

        describe "state(:<state_name> => {event(:<event_name1>) => :<new_state_name>, event(:<event_name2>) => :<new_state_name>})" do
          before(:each) do
            @flow = @target.state_flow(:status) do
              state :foo => {event(:event1) => :bar, event(:event2) => :baz}
              state :bar => {event(:event1) => :baz, event(:event2) => :foo}, :lock => true
              state :baz => {event(:event1) => :foo, event(:event2) => :bar, :lock => true}
            end
          end
          it("check") { check_flow_with_event }
          it("inspect") {check_inspect_with_event }
        end

        describe "state( :<state_name> => [ {event(:<event_name1>) => :<new_state_name>, event(:<event_name2>) => :<new_state_name>} ] )" do
          before(:each) do
            @flow = @target.state_flow(:status) do
              state :foo => [{event(:event1) => :bar, event(:event2) => :baz}]
              state :bar => [{event(:event1) => :baz, event(:event2) => :foo}], :lock => true
              state :baz => [{event(:event1) => :foo, event(:event2) => :bar, :lock => true}]
            end
          end
          it("check") { check_flow_with_event }
          it("inspect") {check_inspect_with_event }
        end

        describe "state( :<state_name> => [ {event(:<event_name1>) => :<new_state_name>}, {event(:<event_name2>) => :<new_state_name>} ] )" do
          before(:each) do
            @flow = @target.state_flow(:status) do
              state :foo => [{event(:event1) => :bar}, {event(:event2) => :baz}]
              state :bar => [{event(:event1) => :baz}, {event(:event2) => :foo}], :lock => true
              state :baz => [{event(:event1) => :foo, :lock => true}, {event(:event2) => :bar, :lock => true}]
            end
          end
          it("check") { check_flow_with_event }
          it("inspect") {check_inspect_with_event }
        end
      end

      describe "with event and actions" do
        def check_flow_with_event_and_actions
          @flow[:foo].key.should == :foo
          @flow[:foo].events.should_not == []
          @flow[:foo].event_for(:event1).should_not be_nil
          @flow[:foo].event_for(:event1).success_key.should == :bar
          @flow[:foo].event_for(:event2).success_key.should == :baz
          @flow[:foo].event_for(:event1).action.name.should == :hoge
          @flow[:foo].event_for(:event2).action.name.should == :hage
          @flow[:foo].event_for(:event1).action.success_key.should == :bar
          @flow[:foo].event_for(:event2).action.success_key.should == :baz
          @flow[:foo].action.should be_nil
          @flow[:foo].success_key.should == nil
          @flow[:foo].options.should == {}
          @flow[:bar].key.should == :bar
          @flow[:bar].event_for(:event1).should_not be_nil
          @flow[:bar].event_for(:event1).success_key.should == :baz
          @flow[:bar].event_for(:event2).success_key.should == :foo
          @flow[:bar].event_for(:event1).action.name.should == :hoge
          @flow[:bar].event_for(:event2).action.name.should == :hage
          @flow[:bar].event_for(:event1).action.success_key.should == :baz
          @flow[:bar].event_for(:event2).action.success_key.should == :foo
          @flow[:bar].event_for(:event1).action.lock.should == true
          @flow[:bar].event_for(:event2).action.lock.should == true
          @flow[:bar].action.should be_nil
          @flow[:bar].success_key.should == nil
          @flow[:baz].key.should == :baz
          @flow[:baz].event_for(:event1).should_not be_nil
          @flow[:baz].event_for(:event1).success_key.should == :foo
          @flow[:baz].event_for(:event2).success_key.should == :bar
          @flow[:baz].event_for(:event1).action.name.should == :hoge
          @flow[:baz].event_for(:event2).action.name.should == :hage
          @flow[:baz].event_for(:event1).action.success_key.should == :foo
          @flow[:baz].event_for(:event2).action.success_key.should == :bar
          @flow[:baz].event_for(:event1).action.lock.should == true
          @flow[:baz].event_for(:event2).action.lock.should == true
          @flow[:baz].action.should be_nil
          @flow[:baz].success_key.should == nil
        end

        def check_inspect_with_event_and_actions
          klass_name = @target.name
          @flow.inspect.should == '<StateFlow::Base @attr_name=:status @attr_key_name=:status_key' <<
            " @klass=#{@target.name.inspect}" <<
            ' @entries=[' <<
              '<StateFlow::Entry @key=:foo @events=[' << 
                '<StateFlow::Event @name=:event1 @action=<StateFlow::NamedAction @name=:hoge @success_key=:bar>>, ' << 
                '<StateFlow::Event @name=:event2 @action=<StateFlow::NamedAction @name=:hage @success_key=:baz>>' << 
              ']>, ' <<
              '<StateFlow::Entry @key=:bar @events=[' << 
                '<StateFlow::Event @name=:event1 @action=<StateFlow::NamedAction @name=:hoge @success_key=:baz @lock=true>>, ' << 
                '<StateFlow::Event @name=:event2 @action=<StateFlow::NamedAction @name=:hage @success_key=:foo @lock=true>>' << 
              ']>, ' <<
              '<StateFlow::Entry @key=:baz @events=[' << 
                '<StateFlow::Event @name=:event1 @action=<StateFlow::NamedAction @name=:hoge @success_key=:foo @lock=true>>, ' << 
                '<StateFlow::Event @name=:event2 @action=<StateFlow::NamedAction @name=:hage @success_key=:bar @lock=true>>' << 
              ']>' <<
            ']>'
        end

        describe "state( :<state_name> => { event(:<event_name1>) => { action(:<method_name1>) => :<new_state_name>}, event(:<event_name2>) => {action(:<method_name1>) => :<new_state_name>} }" do
          before(:each) do
            @flow = @target.state_flow(:status) do
              state :foo => [{event(:event1) => {action(:hoge) => :bar}, event(:event2) => {action(:hage) => :baz}}]
              state :bar => [{event(:event1) => {action(:hoge) => :baz}, event(:event2) => {action(:hage) => :foo}}], :lock => true
              state :baz => [{event(:event1) => {action(:hoge) => :foo}, event(:event2) => {action(:hage) => :bar}, :lock => true}]
            end
          end
          it("check") { check_flow_with_event_and_actions }
          it("inspect") {check_inspect_with_event_and_actions }
        end

        describe "state( :<state_name> => [ { event(:<event_name1>) => { action(:<method_name1>) => :<new_state_name>}, event(:<event_name2>) => {action(:<method_name1>) => :<new_state_name>} } ]" do
          before(:each) do
            @flow = @target.state_flow(:status) do
              state :foo => [{event(:event1) => {action(:hoge) => :bar}, event(:event2) => {action(:hage) => :baz}}]
              state :bar => [{event(:event1) => {action(:hoge) => :baz}, event(:event2) => {action(:hage) => :foo}}], :lock => true
              state :baz => [{event(:event1) => {action(:hoge) => :foo, :lock => true}, event(:event2) => {action(:hage) => :bar, :lock => true}}]
            end
          end
          it("check") { check_flow_with_event_and_actions }
          it("inspect") {check_inspect_with_event_and_actions }
        end
        
      end
    end
    
    describe "invalid arguments" do
    end
    
  end
  
end
