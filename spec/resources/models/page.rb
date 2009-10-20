# -*- coding: utf-8 -*-
class Page < ActiveRecord::Base
  selectable_attr :status_cd do
    entry '00', :created        , '生成済'
    entry '01', :editable       , '編集可'
    entry '02', :approving      , '承認中'
    entry '03', :approved       , '承認済'
    entry '04', :waiting_publish, '公開待ち'
    entry '05', :publishing     , '公開処理中'
    entry '06', :publishing_done, '公開済'
    entry '07', :published      , '公開済'
    entry '08', :publish_failure, '公開失敗'
    entry '09', :waiting_closing, '終了待ち'
    entry '10', :closing        , '終了処理中'
    entry '11', :closed         , '終了済'
    entry '12', :closing_failure, '終了失敗'
  end

  state_flow(:status) do
    state :created => {action(:make_ediable) => :editable, :lock => true}
    state :editable  => {event(:apply) => :approving}
    state :approving => {
      event(:approve) => :approved,
      event(:reject)  => :editable
    }
    state :approved  => {event(:publish) => :waiting_publish}
    
    with_options(:failure => :publish_failure) do |publishing|
      publishing.state :waiting_publish => :publishing, :lock => true
      # publishing.state :publishing => {action(:start_publish) => :publishing_done}
      publishing.state :publishing => action(:start_publish)
      publishing.state :publish_failure
      publishing.state :publishing_done => :published, :if => :accessable?
    end

    state :published => {event(:close) => :waiting_closing}

    with_options(:failure => :closing_failure) do |closing|
      closing.state :waiting_closing => :closing, :lock => true
      closing.state :closing => {action(:start_closing) => :closing}
      closing.state :closing_failure
      closing.state :closing_done => :closed, :unless => :accessable?
    end

    state :closed
  end

  def make_ediable
  end

  def start_publish
  end

  def start_closing
  end

  def accessable?
  end

  
end
