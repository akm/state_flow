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
      it "state(:<state_name>)" do
        flow = @target.state_flow(:status) do
          state :foo
          state :bar, :lock => true
        end
        flow[:foo].key.should == :foo
        flow[:foo].events.should == []
        flow[:foo].success_key.should == nil
        flow[:foo].options.should == {}
        flow[:bar].key.should == :bar
        flow[:bar].events.should == []
        flow[:bar].success_key.should == nil
        flow[:bar].action.lock.should == true
        flow[:bar].action.lock.should == true
      end

      it "state(:<state_name> => nil)" do
        flow = @target.state_flow(:status) do
          state :foo => nil
          state :bar => nil, :lock => true
        end
        flow[:foo].key.should == :foo
        flow[:foo].events.should == []
        flow[:foo].success_key.should == nil
        flow[:foo].options.should == {}
        flow[:bar].key.should == :bar
        flow[:bar].events.should == []
        flow[:bar].success_key.should == nil
        flow[:bar].action.lock.should == true
      end
      
      it "state(:<state_name> => :<new_state_name>)" do
        flow = @target.state_flow(:status) do
          state :foo => :bar
          state :bar => :baz, :lock => true
          state({:baz => :foo}, {:lock => true})
        end
        flow[:foo].key.should == :foo
        flow[:foo].events.should == []
        flow[:foo].success_key.should == :bar
        flow[:foo].options.should == {}
        flow[:bar].key.should == :bar
        flow[:bar].events.should == []
        flow[:bar].success_key.should == :baz
        flow[:bar].action.lock.should == true
        flow[:baz].key.should == :baz
        flow[:baz].events.should == []
        flow[:baz].success_key.should == :foo
        flow[:baz].action.lock.should == true
      end
      
      it "state(:<state_name> => :<new_state_name>, :failure => <:failure_state>)" do
        flow = @target.state_flow(:status) do
          state :foo => :bar, :failure => :baz
          state :bar => :baz, :lock => true
          state({:baz => :foo}, {:lock => true})
        end
        flow[:foo].key.should == :foo
        flow[:foo].events.should == []
        flow[:foo].success_key.should == :bar
        flow[:foo].failure_key.should == :baz
        flow[:foo].options.should == {}
        flow[:bar].key.should == :bar
        flow[:bar].events.should == []
        flow[:bar].success_key.should == :baz
        flow[:bar].action.lock.should == true
        flow[:baz].key.should == :baz
        flow[:baz].events.should == []
        flow[:baz].success_key.should == :foo
        flow[:baz].action.lock.should == true
      end
      
      it "state(:<state_name> => action(:<method_name>))" do
        flow = @target.state_flow(:status) do
          state :foo => action(:hoge)
          state :bar => action(:hoge), :lock => true
          state({:baz => action(:hoge)}, {:lock => true})
        end
        flow[:foo].key.should == :foo
        flow[:foo].events.should == []
        flow[:foo].action.name.should == :hoge
        flow[:foo].success_key.should == nil
        flow[:foo].options.should == {}
        flow[:bar].key.should == :bar
        flow[:bar].events.should == []
        flow[:bar].action.name.should == :hoge
        flow[:bar].success_key.should == nil
        flow[:bar].action.lock.should == true
        flow[:baz].key.should == :baz
        flow[:baz].events.should == []
        flow[:baz].action.name.should == :hoge
        flow[:baz].success_key.should == nil
        flow[:baz].action.lock.should == true
      end
      
      it "state(:<state_name> => {action(:<method_name>) => :<new_state_name>})" do
        flow = @target.state_flow(:status) do
          begin
            state :foo => {action(:hoge) => :bar}
            state :bar => {action(:hoge) => :baz}, :lock => true
            state :baz => {action(:hoge) => :foo, :lock => true}
          rescue Exception
            puts $!.backtrace.join("\n  ")
            raise
          end
        end
        flow[:foo].key.should == :foo
        flow[:foo].events.should == []
        flow[:foo].action.name.should == :hoge
        flow[:foo].action.success_key.should == :bar
        flow[:foo].success_key.should == :bar
        flow[:foo].options.should == {}
        flow[:bar].key.should == :bar
        flow[:bar].events.should == []
        flow[:bar].action.name.should == :hoge
        flow[:bar].action.success_key.should == :baz
        flow[:bar].success_key.should == :baz
        flow[:bar].action.lock.should == true
        flow[:baz].key.should == :baz
        flow[:baz].events.should == []
        flow[:baz].action.name.should == :hoge
        flow[:baz].action.success_key.should == :foo
        flow[:baz].success_key.should == :foo
        flow[:baz].action.lock.should == true
      end
      
      def check_flow_with_event(flow)
        flow[:foo].key.should == :foo
        flow[:foo].events.should_not == []
        flow[:foo].event_for(:event1).should_not be_nil
        flow[:foo].event_for(:event1).success_key.should == :bar
        flow[:foo].event_for(:event2).success_key.should == :baz
        flow[:foo].action.should be_nil
        flow[:foo].success_key.should == nil
        flow[:foo].options.should == {}
        flow[:bar].key.should == :bar
        flow[:bar].event_for(:event1).should_not be_nil
        flow[:bar].event_for(:event1).success_key.should == :baz
        flow[:bar].event_for(:event2).success_key.should == :foo
        flow[:bar].event_for(:event1).action.lock.should == true
        flow[:bar].event_for(:event2).action.lock.should == true
        flow[:bar].action.should be_nil
        flow[:bar].success_key.should == nil
        flow[:baz].key.should == :baz
        flow[:baz].event_for(:event1).should_not be_nil
        flow[:baz].event_for(:event1).success_key.should == :foo
        flow[:baz].event_for(:event2).success_key.should == :bar
        flow[:baz].event_for(:event1).action.lock.should == true
        flow[:baz].event_for(:event2).action.lock.should == true
        flow[:baz].action.should be_nil
        flow[:baz].success_key.should == nil
      end

      it "state(:<state_name> => {event(:<event_name1>) => :<new_state_name>, event(:<event_name2>) => :<new_state_name>})" do
        flow = @target.state_flow(:status) do
          state :foo => {event(:event1) => :bar, event(:event2) => :baz}
          state :bar => {event(:event1) => :baz, event(:event2) => :foo}, :lock => true
          state :baz => {event(:event1) => :foo, event(:event2) => :bar, :lock => true}
        end
        check_flow_with_event(flow)
      end
      
      it "state( :<state_name> => [ {event(:<event_name1>) => :<new_state_name>, event(:<event_name2>) => :<new_state_name>} ] )" do
        flow = @target.state_flow(:status) do
          state :foo => [{event(:event1) => :bar, event(:event2) => :baz}]
          state :bar => [{event(:event1) => :baz, event(:event2) => :foo}], :lock => true
          state :baz => [{event(:event1) => :foo, event(:event2) => :bar, :lock => true}]
        end
        check_flow_with_event(flow)
      end
      
      it "state( :<state_name> => [ {event(:<event_name1>) => :<new_state_name>}, {event(:<event_name2>) => :<new_state_name>} ] )" do
        flow = @target.state_flow(:status) do
          state :foo => [{event(:event1) => :bar}, {event(:event2) => :baz}]
          state :bar => [{event(:event1) => :baz}, {event(:event2) => :foo}], :lock => true
          state :baz => [{event(:event1) => :foo, :lock => true}, {event(:event2) => :bar, :lock => true}]
        end
        check_flow_with_event(flow)
      end
      
      def check_flow_with_event_and_actions(flow)
        flow[:foo].key.should == :foo
        flow[:foo].events.should_not == []
        flow[:foo].event_for(:event1).should_not be_nil
        flow[:foo].event_for(:event1).success_key.should == :bar
        flow[:foo].event_for(:event2).success_key.should == :baz
        flow[:foo].event_for(:event1).action.name.should == :hoge
        flow[:foo].event_for(:event2).action.name.should == :hage
        flow[:foo].event_for(:event1).action.success_key.should == :bar
        flow[:foo].event_for(:event2).action.success_key.should == :baz
        flow[:foo].action.should be_nil
        flow[:foo].success_key.should == nil
        flow[:foo].options.should == {}
        flow[:bar].key.should == :bar
        flow[:bar].event_for(:event1).should_not be_nil
        flow[:bar].event_for(:event1).success_key.should == :baz
        flow[:bar].event_for(:event2).success_key.should == :foo
        flow[:bar].event_for(:event1).action.name.should == :hoge
        flow[:bar].event_for(:event2).action.name.should == :hage
        flow[:bar].event_for(:event1).action.success_key.should == :baz
        flow[:bar].event_for(:event2).action.success_key.should == :foo
        flow[:bar].event_for(:event1).action.lock.should == true
        flow[:bar].event_for(:event2).action.lock.should == true
        flow[:bar].action.should be_nil
        flow[:bar].success_key.should == nil
        flow[:baz].key.should == :baz
        flow[:baz].event_for(:event1).should_not be_nil
        flow[:baz].event_for(:event1).success_key.should == :foo
        flow[:baz].event_for(:event2).success_key.should == :bar
        flow[:baz].event_for(:event1).action.name.should == :hoge
        flow[:baz].event_for(:event2).action.name.should == :hage
        flow[:baz].event_for(:event1).action.success_key.should == :foo
        flow[:baz].event_for(:event2).action.success_key.should == :bar
        flow[:baz].event_for(:event1).action.lock.should == true
        flow[:baz].event_for(:event2).action.lock.should == true
        flow[:baz].action.should be_nil
        flow[:baz].success_key.should == nil
      end

      it "state( :<state_name> => { event(:<event_name1>) => { action(:<method_name1>) => :<new_state_name>}, event(:<event_name2>) => {action(:<method_name1>) => :<new_state_name>} }" do
        flow = @target.state_flow(:status) do
          state :foo => [{event(:event1) => {action(:hoge) => :bar}, event(:event2) => {action(:hage) => :baz}}]
          state :bar => [{event(:event1) => {action(:hoge) => :baz}, event(:event2) => {action(:hage) => :foo}}], :lock => true
          state :baz => [{event(:event1) => {action(:hoge) => :foo}, event(:event2) => {action(:hage) => :bar}, :lock => true}]
        end
        check_flow_with_event_and_actions(flow)
      end

      it "state( :<state_name> => { event(:<event_name1>) => { action(:<method_name1>) => :<new_state_name>}, event(:<event_name2>) => {action(:<method_name1>) => :<new_state_name>} }" do
        flow = @target.state_flow(:status) do
          state :foo => [{event(:event1) => {action(:hoge) => :bar}, event(:event2) => {action(:hage) => :baz}}]
          state :bar => [{event(:event1) => {action(:hoge) => :baz}, event(:event2) => {action(:hage) => :foo}}], :lock => true
          state :baz => [{event(:event1) => {action(:hoge) => :foo, :lock => true}, event(:event2) => {action(:hage) => :bar, :lock => true}}]
        end
        check_flow_with_event_and_actions(flow)
      end
      
    end
    
    describe "invalid arguments" do
      
    end
    
  end
  
end
