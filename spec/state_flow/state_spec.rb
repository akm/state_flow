# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), '../spec_helper')

describe StateFlow::State do
  
  describe "with Order" do
    describe "from waiting_settling" do
      describe ":cash_on_delivery" do
        before do
          StateFlow::Log.delete_all
          Order.delete_all
          @order = Order.new
          @order.product_name = "Beautiful Code"
          @order.payment_type = :cash_on_delivery
          @order.status_key = :waiting_settling
          @order.save!
          Order.count == 1

          @flow = Order.state_flow_for(:status_cd)
          @state = @flow.origin
          @state.name.should == :waiting_settling
        end

        it "should recieve guard process" do
          g0 = @state.guards[0] # :pay_cash_on_delivery?
          g0.should_receive(:process).with(@order).and_return{|order| g0.action.process(order)}
          @order.process_status_cd
          @order.status_key.should == :stock_error
        end
        
        it "should recieve action process #0" do
          g0 = @state.guards[0] # :pay_cash_on_delivery?
          a0 = g0.action # :reserve_point
          a0.should_receive(:process).with(@order).and_return{|order| a0.action.process(order)}
          @order.process_status_cd
          @order.status_key.should == :stock_error
        end
        
        it "should recieve action process #1" do
          g0 = @state.guards[0] # :pay_cash_on_delivery?
          a0 = g0.action # :reserve_point
          a1 = a0.action # :reserve_stock
          a1.should_receive(:process).with(@order).and_return{|order| a1.events[0].process(order)}
          @order.process_status_cd
          @order.status_key.should == :deliver_preparing
        end

        describe "action event invocation" do
          before do
            g0 = @state.guards[0] # :pay_cash_on_delivery?
            a0 = g0.action # :reserve_point
            @a1 = a0.action # :reserve_stock
          end

          it "should recieve action events_for_action" do
            @order.should_receive(:reserve_stock).and_return(nil)
            @a1.should_receive(:event_for_action_result).and_return(@a1.events[0])
            @order.process_status_cd
            @order.status_key.should == :deliver_preparing
          end

          it "should recieve action events_for_action" do
            @order.should_receive(:reserve_stock).and_return(:reserve_stock_ok)
            @a1.should_receive(:event_for_action_result).and_return(@a1.events[1])
            @order.process_status_cd
            @order.status_key.should == :stock_error
          end
        end

        it "should recieve action event update_to_destination" do
          @order.should_receive(:reserve_stock).and_return(:reserve_stock_ok)
          @order.process_status_cd
          @order.status_key.should == :deliver_preparing
        end
                
        it "should recieve action event update_to_destination #2" do
          @order.should_receive(:reserve_stock).and_return(nil)
          @order.process_status_cd
          @order.status_key.should == :stock_error
        end
      end

      describe ":credit_card" do
        before do
          StateFlow::Log.delete_all
          Order.delete_all
          @order = Order.new
          @order.product_name = "Beautiful Code"
          @order.payment_type = :credit_card
          @order.status_key = :waiting_settling
          @order.save!
          Order.count == 1

          @flow = Order.state_flow_for(:status_cd)
          @state = @flow.origin
          @state.name.should == :waiting_settling
        end

        describe ":reserve_stock_ok" do
          before do
            @order.should_receive(:reserve_stock).and_return(:reserve_stock_ok)
          end

          it "should recieve guard process" do
            g1 = @state.guards[1] # :pay_cash_on_delivery?
            g1.should_receive(:process).with(@order).and_return{|order| g1.action.process(order)}
            @order.process_status_cd
          end

          it "should recieve action event_for_action_result" do
            g1 = @state.guards[1] # :pay_cash_on_delivery?
            a0 = g1.action
            a1 = a0.action
            a1.event_for_action_result(:reserve_stock_ok).should == a1.events[0]
            a1.should_receive(:event_for_action_result).and_return(a1.events[0])
            @order.process_status_cd
          end

          it "should recieve evnet process" do
            g1 = @state.guards[1] # :pay_cash_on_delivery?
            a0 = g1.action
            a1 = a0.action
            e0 = a1.events[0]
            e0.should_receive(:process).with(@order).and_return{|order| e0.guards[1].process(order)}
            @order.process_status_cd
          end

          it "should recieve evnet process" do
            g1 = @state.guards[1] # :pay_cash_on_delivery?
            a0 = g1.action
            a1 = a0.action
            e0 = a1.events[0]
            g1 = e0.guards[1]
            g1.should_receive(:process).with(@order).and_return{|order| g1.update_to_destination(order)}
            @order.process_status_cd
          end
        end
        
        
      end
    
    end
  end

end
