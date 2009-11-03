# -*- coding: utf-8 -*-
class Order < ActiveRecord::Base

  class StockShortageError < StandardError
  end

  selectable_attr :status_cd do
    entry '00', :waiting_settling , '決済前'
    entry '01', :online_settling  , '決済中'
    entry '02', :receiving        , '入金待ち'
    entry '03', :deliver_preparing, '配送準備中'
    entry '04', :deliver_requested, '配送指示済'
    entry '05', :delivered        , '配送済'
    entry '06', :deliver_notified , '配送案内済'
    entry '07', :cancel_requested , 'キャンセル依頼中'
    entry '08', :canceled         , 'キャンセル完了'
    entry '19', :settlement_error , '決済NG'
    entry '10', :stock_error      , '在庫不足エラー'
    entry '11', :internal_error   , '内部エラー'
    entry '12', :external_error   , '外部エラー'
  end
  
  state_flow(:status_cd) do
    origin(:waiting_settling)

    group(:valid) do # 正常系
      # recoverの順番は重要。Exceptionを先に書くと全ての例外は:internal_errorになってしまいます。
      recover(:'Net::HTTPHeaderSyntaxError').to(:external_error)
      recover(:'Net::ProtocolError').to(:external_error)
      recover(:'Exception').to(:internal_error)

      group(:auto_cancelable) do # 自動キャンセル可
        
        from(:waiting_settling) do
          # actionは続けて書くこともできます。
          guard(:pay_cash_on_delivery?).action(:reserve_point).action(:reserve_stock){
            event(:reserve_stock_ok).to(:deliver_preparing)
            event_else.action(:delete_point).to(:stock_error)
          }
          # guard_elseは他のガード(群)に該当しなかった場合のガードです。
          guard_else.action(:reserve_point).action(:reserve_stock, :temporary => true){
            # 一行で書けない処理群はブロックを用いて書くことができます。
            event(:reserve_stock_ok){
              guard(:bank_deposit?).action(:send_mail_thanks).to(:receiving)
              guard(:credit_card?).to(:online_settling)
              guard(:foreign_payment?).action(:settle).to(:online_settling)
            }
            event_else{
              guard(:foreign_payment?).action(:delete_point).action(:send_mail_stock_shortage)
            }.to(:stock_error)
            
            # この上の書き方は以下と同じ意味を持ちます。
            # event_else{
            #   guard(:foreign_payment?).action(:send_mail_stock_shortage).to(:stock_error)
            #   guard_else.to(:stock_error)
            # }
          }
          
          # sqlite3ではテスト中にロールバックすると、transactionの中なのに
          #   cannot rollback - no transaction is active 
          # とか言われちゃうので、rolling_backをfalseにしてます。
          recover(StockShortageError, :rolling_back => (ENV['DB'] || 'sqlite3') != 'sqlite3').to(:stock_error)
        end
        
        from(:online_settling) do
          guard(:credit_card?).action(:settle){
            event(:settlement_ok).action(:reserve_stock).action(:send_mail_thanks).to(:deliver_preparing)
            event_else.action(:release_stock).action(:delete_point).to(:settlement_error)
          }
          guard(:foreign_payment?){
            event(:settlement_ok).to(:deliver_preparing)
            event_else{
              action(:release_stock)
              action(:delete_point)
              action(:send_mail_invalid_purchage)
              to(:settlement_error)
            }
          }
        end
          
        from :receiving do
          event(:confirm_receiving) {
            action :reserve_stock
            action :send_mail_payment_complete
            to :deliver_preparing
          }
        end
        
        from :deliver_preparing do
          event(:deliver_request).
            action(:reduce_stock).
            action(:send_mail_deliver_request).
            to(:deliver_requested)
        end
        
        event(:cancel_request) {
          action(:send_mail_cancel_requested)
        }.to(:cancel_requested)

        event(:cancel) {
          action(:release_reserve)
          action(:delete_point)
          action(:send_mail_cancel_complete)
        }.to(:canceled)
      end

      from(:deliver_requested) do
        event(:deliver).action(:send_mail_shipping_for_shop).action(:send_mail_shipping_for_customer).to(:delivered)
        event(:cancel_request).action(:send_mail_cancel_requested).to(:cancel_requested)
      end
      
      from(:delivered) do
        event(:deliver_notify).action(:send_mail_deliver_notification).to(:deliver_notified)
      end
      
      termination(:deliver_notified) # 終端
      
      state_group(:canceling) do # 正常なキャンセル系
        from :cancel_requested do
          event(:accept_cancel) {
            action(:release_reserve)
            action(:delete_point)
            action(:send_mail_cancel_complete)
          }.to(:canceled)
        end
        
        termination(:canceled) # 終端
      end
    end
    
    group(:error) do # 異常系
      from(:settlement_error) do
        action(:send_mail_settlement_error)
        # to(:settlement_error) # 遷移しない
      end
      
      state(:stock_error)
      state(:internal_error)
      state(:external_error)

      termination # 終端
    end
  end

  validates_presence_of :product_name

  attr_accessor :payment_type
  def pay_cash_on_delivery?; payment_type == :cash_on_delivery; end
  def bank_deposit?        ; payment_type == :bank_deposit    ; end
  def credit_card?         ; payment_type == :credit_card     ; end
  def foreign_payment?     ; payment_type == :foreign_payment ; end

  attr_accessor :reserve_stock_result

  def reserve_point; end
  def delete_point; end

  def reserve_stock(*args); end
  def release_stock; end
  def reduce_stock; end

  def settle; end

  def send_mail_thanks; end
  def send_mail_stock_shortage; end
  def send_mail_invalid_purchage; end
  def send_mail_deliver_request; end
  def send_mail_cancel_requested; end
  def send_mail_cancel_complete; end
  def send_mail_shipping_for_shop; end
  def send_mail_shipping_for_customer; end
  def send_mail_deliver_notification; end
  def send_mail_settlement_error; end

end
