# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Page :created => :editable" do
  before(:each) do
    StateFlow::Log.delete_all
    Page.delete_all
  end

  def log(msg)
    ActiveRecord::Base.logger.debug(msg)
  end

  def next_step
    @current = @schedules.shift
    @executed << @current if @current
    log "next must be #{@current.inspect}"
  end

  def wait_on(step)
    log "#{Thread.current[:name]} wait_on #{step.inspect}" << (@current == step ? '' : " but #{@current.inspect} now")
    while @current != step; end
    log "#{Thread.current[:name]} met #{step.inspect}"
    next_step
  end

  def execute_parallel(schedules, options = nil)
    Thread.current[:name] = 'main'
    log "-" * 100
    options = {
      :with_inner_transaction => false,
      :with_outer_transaction => false
    }.update(options || {})
    log options.inspect
    @schedules = schedules.dup
    @executed = []
    p1 = Page.create(:name => "top page")
    @t1, @t2 = %w(t1 t2).map do |name|
      Thread.new do
        # Thread.current.abort_on_exception = true
        Thread.current[:name] = name
        Thread.current[:connection_id] = ActiveRecord::Base.connection.object_id
        
        log("connection_id => #{Thread.current[:connection_id]}")
        
        wait_on(:"#{name}_before_process_state")
        begin
          Page.process_state(:status_cd, :created, 
            :transactional => options[:with_inner_transaction]) do |action|
            wait_on :"#{name}_before_action_proceed"
            action.record.name = "updated by #{name}"
            begin
              action.proceed
              wait_on :"#{name}_after_action_proceed"
            rescue Exception
              wait_on :"#{name}_error_in_process"
            end
          end
        rescue Exception
          log $!
          log $!.backtrace.join("\n  ")
          wait_on :"#{name}_error"
          # raise
        end
        wait_on :"#{name}_after_process_state"
      end
    end
    next_step
        
    Page.transaction_if_need(options[:with_outer_transaction]) do
      @t1.join(5)
      @t2.join(5)
    end
        
    @t1[:connection_id].should_not == @t2[:connection_id]
  end
  
  FLOWS = {
    :no_lock => [
      # ロックが発生しないパターン
      :t1_before_process_state,
      :t1_before_action_proceed,
      :t1_after_action_proceed,
      :t2_before_process_state,
      :t2_after_process_state,
      :t1_after_process_state,
    ].freeze,
    :t2_timeout => [
      # t1がコミットするまでt2のprocess_state内のselectは動かないので、
      # 以下のパターンはタイムアウトするまで時間が掛かります。
      :t1_before_process_state,
      :t1_before_action_proceed,
      :t2_before_process_state, 
      :t1_after_action_proceed,
      :t2_error,
      :t1_after_process_state,
      :t2_after_process_state,
    ]
  }

  # t1がコミットするまでt2のprocess_state内のselectは動かないので、
  # t2がトランザクションを開始した後、findを実行した後に、:t2_errorを
  # 待たずにt1をコミットさせ・・・たかったんだけど、どうも1プロセスから
  # 複数のスレッドでロックの発生する処理を行おうとするとどうにもうまくいかない。
  # なので、このテストからは省きます。残念。
  # LOCKED_FLOW_1 = [
  #   :t1_before_process_state,
  #   :t1_before_action_proceed,
  #   :t2_before_process_state,
  #   :t1_after_action_proceed,
  #   :t1_after_process_state,
  #   :t2_after_process_state,
  # ].freeze

  # t1がコミットするまでt2のprocess_state内のselectは動かないので、
  # :t1_after_action_proceed が :t2_after_process_state よりも後にある
  # 以下のパターンは矛盾しています。なのでテスト対象外です。
  # CONFLICT_FLOW_1 = [
  #   :t1_before_process_state,
  #   :t1_before_action_proceed,
  #   :t2_before_process_state, 
  #   :t2_after_process_state,
  #   :t1_after_action_proceed,
  #   :t1_after_process_state,
  # ].freeze

  case ENV['DB'] || 'sqlite3'

  when 'mysql' then
    [:no_lock, :t2_timeout].each do |flow_name|
      flow = FLOWS[flow_name]
      
      describe flow_name.to_s do
        [false, true].each do |outer_transactional|
          describe ":with_outer_transaction => #{outer_transactional}" do

            it ":with_inner_transaction => false" do
              execute_parallel(flow,
                :with_inner_transaction => false,
                :with_outer_transaction => outer_transactional)
              Page.first.name.should == 'updated by t1'
              @executed.should == flow
            end

            it ":with_inner_transaction :all " do
              execute_parallel(flow,
                :with_inner_transaction => :all,
                :with_outer_transaction => outer_transactional)
              if (flow_name == :t2_timeout) && !outer_transactional
                Page.first.name.should == 'top page'
                @executed.should == [
                  :t1_before_process_state, :t1_before_action_proceed, :t2_before_process_state, :t1_after_action_proceed, :t2_error]
              else
                Page.first.name.should == 'updated by t1'
                @executed.should == flow
              end
            end

            it ":with_inner_transaction :each " do
              execute_parallel(flow,
                :with_inner_transaction => :each,
                :with_outer_transaction => outer_transactional)
              Page.first.name.should == 'updated by t1'
              @executed.should == flow
            end
            
          end
        end
      end
    end
  
  when 'postgresql' then
    [:no_lock, :t2_timeout].each do |flow_name|
      flow = FLOWS[flow_name]
      
      describe flow_name.to_s do
        [false, true].each do |outer_transactional|
          describe ":with_outer_transaction => #{outer_transactional}" do

            expected_flow = [:t1_before_process_state, :t1_before_action_proceed, :t2_before_process_state, :t1_after_action_proceed, :t2_error]

            it ":with_inner_transaction => false" do
              execute_parallel(flow,
                :with_inner_transaction => false,
                :with_outer_transaction => outer_transactional)
              Page.first.name.should == 'updated by t1'
              if flow_name == :t2_timeout
                @executed.should == expected_flow
              else
                @executed.should == flow
              end
            end

#             it ":with_inner_transaction :all " do
#               execute_parallel(flow,
#                 :with_inner_transaction => :all,
#                 :with_outer_transaction => outer_transactional)
#               if (flow_name == :t2_timeout) && !outer_transactional
#                 Page.first.name.should == 'top page'
#                 @executed.should == [
#                   :t1_before_process_state, :t1_before_action_proceed, :t2_before_process_state, :t1_after_action_proceed, :t2_error]
#               else
#                 Page.first.name.should == 'updated by t1'
#                 @executed.should == flow
#               end
#             end

            it ":with_inner_transaction :each " do
              execute_parallel(flow,
                :with_inner_transaction => :each,
                :with_outer_transaction => outer_transactional)
              Page.first.name.should == 'updated by t1'
              if flow_name == :t2_timeout
                @executed.should == expected_flow
              else
                @executed.should == flow
              end
            end
            
          end
        end
      end
    end

  when 'sqlite3' then
    # [:no_lock, :t2_timeout].each do |flow_name|
    [:no_lock].each do |flow_name|
      flow = FLOWS[flow_name]
      
      describe flow_name.to_s do
        [false, true].each do |outer_transactional|
          describe ":with_outer_transaction => #{outer_transactional}" do

            it ":with_inner_transaction => false" do
              execute_parallel(flow,
                :with_inner_transaction => false,
                :with_outer_transaction => outer_transactional)
              Page.first.name.should == 'updated by t1'
              if (flow_name == :t2_timeout) && outer_transactional
                @executed.should == [
                  :t1_before_process_state, :t1_before_action_proceed, :t2_before_process_state, :t1_after_action_proceed, :t2_error]
              else
                @executed.should == flow
              end
            end

            it ":with_inner_transaction :all " do
              execute_parallel(flow,
                :with_inner_transaction => :all,
                :with_outer_transaction => outer_transactional)
              if (flow_name == :t2_timeout) && outer_transactional
                Page.first.name.should == 'top page'
                @executed.should == [
                  :t1_before_process_state, :t1_before_action_proceed, :t2_before_process_state, :t1_after_action_proceed, :t2_error]
              else
                Page.first.name.should == 'updated by t1'
                @executed.should == flow
              end
            end

            it ":with_inner_transaction :each " do
              execute_parallel(flow,
                :with_inner_transaction => :each,
                :with_outer_transaction => outer_transactional)
              Page.first.name.should == 'updated by t1'
              @executed.should == flow
            end
            
          end
        end
      end
    end

  end
end
