# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), 'spec_helper')

require 'net/http'

describe Order do
  before(:each) do
    StateFlow::Log.delete_all
    Order.delete_all
  end

  describe "from waiting_settling" do
    describe "cach_on_delivery" do
      before do
        @order = Order.new
        @order.product_name = "Beautiful Code"
        @order.payment_type = :cash_on_delivery
        @order.status_key = :waiting_settling
        @order.save!
        Order.count.should == 1
      end

      it "reserve_stock succeed" do
        @order.should_receive(:reserve_point)
        @order.should_receive(:reserve_stock).once.and_return(:reserve_stock_ok)
        @order.process_status_cd(:save => false)
        @order.status_key.should == :deliver_preparing
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:waiting_settling)}).should == 1
      end

      it "reserve_stock fails" do
        @order.should_receive(:reserve_point)
        @order.should_receive(:reserve_stock).once.and_return(nil)
        @order.process_status_cd(:save => false)
        @order.status_key.should == :stock_error
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:waiting_settling)}).should == 1
      end

      it "reserve_stock failed by Net::ProtoServerError" do
        @order.should_receive(:reserve_point)
        @order.should_receive(:reserve_stock).once.and_raise(Net::ProtoServerError)
        @order.process_status_cd
        @order.status_key.should == :external_error
        # saveされてます。
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:waiting_settling)}).should == 0
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:external_error)}).should == 1
        StateFlow::Log.count.should == 0
      end

      it "reserve_stock failed by IOError" do
        @order.should_receive(:reserve_point)
        @order.should_receive(:reserve_stock).once.and_raise(IOError)
        @order.process_status_cd
        @order.status_key.should == :internal_error
        # saveされてます。
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:waiting_settling)}).should == 0
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:internal_error)}).should == 1
        StateFlow::Log.count.should == 0
      end
    end

    describe "credit_card" do
      before do
        @order = Order.new
        @order.product_name = "Beautiful Code"
        @order.payment_type = :credit_card
        @order.status_key = :waiting_settling
        @order.save!
        Order.count.should == 1
      end

      it "reserve_stock succeed step by step" do
        @order.should_receive(:reserve_point)
        @order.should_receive(:reserve_stock).with(:temporary => true).once.and_return(:reserve_stock_ok)
        @order.process_status_cd(:save => false, :keep_process => false)
        @order.status_key.should == :online_settling
        # saveされてません。
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:waiting_settling)}).should == 1
        @order.save!
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:online_settling)}).should == 1
      end

      it "reserve_stock succeed keep_process" do
        @order.should_receive(:reserve_point)
        @order.should_receive(:reserve_stock).with(:temporary => true).once.and_return(:reserve_stock_ok)
        @order.should_receive(:reserve_stock).once.and_return(:reserve_stock_ok)
        @order.should_receive(:settle).once.and_return(:ok)
        @order.process_status_cd
        @order.status_key.should == :deliver_preparing
        # saveされてます。
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:deliver_preparing)}).should == 1
      end

      it "reserve_stock succeed keep_process but failed" do
        @order.should_receive(:reserve_point)
        @order.should_receive(:reserve_stock).with(:temporary => true).once.and_return(:reserve_stock_ok)
        @order.should_receive(:reserve_stock).once.and_raise(IOError)
        @order.should_receive(:settle).once.and_return(:ok)
        @order.process_status_cd
        @order.status_key.should == :settlement_error # 決済時の例外はすべて:settlement_errorにします。
        # saveされてます。
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:settlement_error)}).should == 1
      end

      it "reserve_stock fails" do
        @order.should_receive(:reserve_point)
        @order.should_receive(:reserve_stock).with(:temporary => true).once.and_return(nil)
        @order.process_status_cd
        @order.status_key.should == :stock_error
        # saveされてます。
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:waiting_settling)}).should == 0
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:stock_error)}).should == 1
        StateFlow::Log.count.should == 0
      end

      it "StockShortageError raised" do
        @order.product_name = "Refactoring"
        @order.should_receive(:reserve_point)
        @order.should_receive(:reserve_stock).with(:temporary => true).once.and_raise(Order::StockShortageError)
        Order.transaction do
          @order.process_status_cd
        end
        @order.status_key.should == :stock_error
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:stock_error)}).should == 1
        # ステータスはちゃんと変わっているけど、他のデータはロールバックされていなければならない
        Order.count(:conditions => {:product_name => "Refactoring"}).should == 0
        Order.count(:conditions => {:product_name => "Beautiful Code"}).should == 1
        # StateFlow::Log.count.should == 1
      end
    end

    describe "bank_deposit" do
      before do
        @order = Order.new
        @order.product_name = "Beautiful Code"
        @order.payment_type = :bank_deposit
        @order.status_key = :waiting_settling
        @order.save!
        Order.count.should == 1
      end

      it "reserve_stock succeed" do
        @order.should_receive(:reserve_point)
        @order.should_receive(:reserve_stock).with(:temporary => true).once.and_return(:reserve_stock_ok)
        @order.should_receive(:send_mail_thanks)
        @order.process_status_cd(:save => false)
        @order.status_key.should == :receiving
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:waiting_settling)}).should == 1
      end

      it "reserve_stock fails" do
        @order.should_receive(:reserve_point)
        @order.should_receive(:reserve_stock).with(:temporary => true).once.and_return(nil)
        @order.process_status_cd(:save => false)
        @order.status_key.should == :stock_error
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:waiting_settling)}).should == 1
      end
    end

    describe "foreign_payment" do
      before do
        @order = Order.new
        @order.product_name = "Beautiful Code"
        @order.payment_type = :foreign_payment
        @order.status_key = :waiting_settling
        @order.save!
        Order.count.should == 1
      end

      it "reserve_stock succeed" do
        @order.should_receive(:reserve_point)
        @order.should_receive(:reserve_stock).with(:temporary => true).once.and_return(:reserve_stock_ok)
        @order.should_receive(:settle)
        @order.process_status_cd(:save => false)
        @order.status_key.should == :online_settling
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:waiting_settling)}).should == 1
      end

      it "reserve_stock fails" do
        @order.should_receive(:reserve_point)
        @order.should_receive(:reserve_stock).with(:temporary => true).once.and_return(nil)
        @order.should_receive(:send_mail_stock_shortage)
        @order.process_status_cd(:save => false)
        @order.status_key.should == :stock_error
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:waiting_settling)}).should == 1
      end
    end
  end
  
  describe "from online_settling" do
    describe "credit_card" do
      before do
        @order = Order.new
        @order.product_name = "Beautiful Code"
        @order.payment_type = :credit_card
        @order.status_key = :online_settling
        @order.save!
        Order.count.should == 1
      end

      it "settle succeed" do
        @order.should_receive(:settle).and_return(:ok)
        @order.should_receive(:reserve_stock)
        @order.should_receive(:send_mail_thanks)
        @order.process_status_cd
        @order.status_key.should == :deliver_preparing
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:deliver_preparing)}).should == 1
      end

      it "settle failed" do
        @order.should_receive(:settle).and_return(nil)
        @order.should_receive(:release_stock)
        @order.should_receive(:delete_point)
        @order.process_status_cd
        @order.status_key.should == :settlement_error
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:settlement_error)}).should == 1
      end

      it "settle failed by IOError" do
        @order.should_receive(:settle).and_raise(IOError)
        @order.should_receive(:release_stock)
        @order.should_receive(:delete_point)
        @order.process_status_cd
        @order.status_key.should == :settlement_error
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:settlement_error)}).should == 1
      end
    end

    describe "foreign_payment" do
      before do
        @order = Order.new
        @order.product_name = "Beautiful Code"
        @order.payment_type = :foreign_payment
        @order.status_key = :online_settling
        @order.save!
        Order.count.should == 1
      end

      it "event must be called as a method" do
        @order.should_not_receive(:settle)
        @order.should_not_receive(:reserve_stock)
        @order.should_not_receive(:send_mail_thanks)
        @order.process_status_cd
        @order.status_key.should == :online_settling
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:online_settling)}).should == 1
      end

      it "event must be called as a method" do
        @order.should_not_receive(:settle)
        @order.should_not_receive(:reserve_stock)
        @order.should_not_receive(:send_mail_thanks)
        @order.settlement_ok # イベント実行
        @order.status_key.should == :deliver_preparing
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:deliver_preparing)}).should == 1
      end

      it "settle failed" do
        @order.should_receive(:release_stock)
        @order.should_receive(:delete_point)
        @order.should_receive(:send_mail_invalid_purchage)
        @order.settlement_ng # イベント実行
        @order.status_key.should == :settlement_error
        Order.count.should == 1
        Order.count(:conditions => {:status_cd => Order.status_id_by_key(:settlement_error)}).should == 1
      end
    end
  end

  describe "structure" do
    it "states" do
      flow = Order.state_flow_for(:status_cd)
      flow.states.length.should == 2
    end

    it "all_states" do
      flow = Order.state_flow_for(:status_cd)
      flow.all_states.values.map{|s| s.name.to_s}.sort.should == [
        :valid, :auto_cancelable, :waiting_settling, :online_settling, 
        :receiving, :deliver_preparing, :deliver_requested, :delivered, 
        :deliver_notified, :canceling, :cancel_requested, :canceled, 
        :error, :settlement_error, :stock_error, :internal_error, :external_error
      ].map{|s| s.to_s}.sort
      flow.all_states.length.should == 17
    end

    it "concrete_states" do
      flow = Order.state_flow_for(:status_cd)
      flow.concrete_states.values.map{|s| s.name.to_s}.sort.should == [
        :waiting_settling, :online_settling, 
        :receiving, :deliver_preparing, :deliver_requested, :delivered, 
        :deliver_notified, :cancel_requested, :canceled, 
        :settlement_error, :stock_error, :internal_error, :external_error
      ].map{|s| s.to_s}.sort
      flow.concrete_states.length.should == 13
    end

    it "origin" do
      flow = Order.state_flow_for(:status_cd)
      flow.origin.class.should == StateFlow::State
      flow.origin.name == :waiting_settling
    end

    it "waiting_settling" do
      flow = Order.state_flow_for(:status_cd)
      state = flow.origin
      state.guards.length.should == 2
      state.events.length.should == 1
      state.action.should be_nil
      g0 = state.guards[0]
      g0.name.should == :pay_cash_on_delivery?
      g0.action.method_name.should == :reserve_point
      g0.action.action.method_name.should == :reserve_stock
      g0.action.action.events.length.should == 2
      g0.action.action.events[0].should be_a(StateFlow::ActionEvent)
      g0.action.action.events[1].should be_a(StateFlow::ActionEvent)
      g0.action.action.events[0].destination.should == :deliver_preparing
      g0.action.action.events[1].action.method_name.should == :delete_point
      g0.action.action.events[1].action.destination.should == :stock_error
      g1 = state.guards[1]
      g1.class.should == StateFlow::Guard
      g1.action.method_name.should == :reserve_point
      a1 = g1.action.action
      a1.method_name.should == :reserve_stock
      a1.method_args.should == [:temporary => true]
      a1.events[0].should be_a(StateFlow::ActionEvent)
      a1.events[1].should be_a(StateFlow::ActionEvent)
      a1.events[0].matcher.should == :reserve_stock_ok
      g00 = a1.events[0].guards[0]
      g00.name.should == :bank_deposit?
      g00.action.method_name.should == :send_mail_thanks
      g00.action.destination.should ==:receiving
      g01 = a1.events[0].guards[1]
      g01.name.should == :credit_card?
      g01.destination.should ==:online_settling
      g02 = a1.events[0].guards[2]
      g02.name.should == :foreign_payment?
      g02.action.method_name.should == :settle
      g02.action.destination.should ==:online_settling
      e1 = a1.events[1]
      e1.should be_a(StateFlow::ActionEvent)
      e1.guards[0].action.method_name.should == :delete_point
      e1.guards[0].action.action.method_name.should == :send_mail_stock_shortage
      e1.destination.should == :stock_error
    end

    it ":online_settling" do
      flow = Order.state_flow_for(:status_cd)
      state = flow.concrete_states[:online_settling]
      g0 = state.guards[0]
      g0.name.should == :credit_card?
      g0.action.method_name.should == :settle
      e0 = g0.action.events[0]
      e0.should be_a(StateFlow::ActionEvent)
      e0.action.method_name.should == :reserve_stock
      e0.action.action.method_name.should == :send_mail_thanks
      e0.action.action.destination.should == :deliver_preparing
      e1 = g0.action.events[1]
      e1.should be_a(StateFlow::ActionEvent)
      e1.action.method_name.should == :release_stock
      e1.action.action.method_name.should == :delete_point
      e1.action.action.destination.should == :settlement_error
      g1 = state.guards[1]
      g1.name.should == :foreign_payment?
      e2 = g1.events[0]
      e2.should be_a(StateFlow::NamedEvent)
      e2.destination.should == :deliver_preparing
      e3 = g1.events[1]
      e3.should be_a(StateFlow::NamedEvent)
      e3.action.method_name.should == :release_stock
      e3.action.action.method_name.should == :delete_point
      e3.action.action.action.method_name.should == :send_mail_invalid_purchage
      e3.action.action.action.destination.should == :settlement_error
    end
  end

end
