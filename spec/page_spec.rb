# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), 'spec_helper')

describe Page do
  before(:each) do
    StateFlow::Log.delete_all
    Page.delete_all
  end

  describe "state_cd_by_key" do
    it "each entries" do
      flow = Page.state_flow_for(:status_cd)
      Page.status_keys.each do |key|
        flow.state_cd_by_key(key).should == Page.status_id_by_key(key)
      end
    end
  end

  describe ":created => :editable" do
    it "valid" do
      p1 = Page.create(:name => "top page")
      p1.should_receive(:make_editable)
      Page.should_receive(:find).with(:first, :lock => true,
        :conditions => ["status_cd = ?", '00'], :order => "id asc").and_return(p1)
      Page.process_state(:status_cd, :created)
      #
      Page.count.should == 1
      Page.count(:conditions => "status_cd = '00'").should == 0
      Page.count(:conditions => "status_cd = '01'").should == 1
    end

    it "valid with another record" do
      p1 = Page.create(:name => "top page")
      p2 = Page.create(:name => "about page")
      p1.should_receive(:make_editable)
      Page.should_receive(:find).with(:first, :lock => true,
        :conditions => ["status_cd = ?", '00'], :order => "id asc").and_return(p1)
      Page.process_state(:status_cd, :created)
      #
      Page.count.should == 2
      Page.count(:conditions => "status_cd = '00'").should == 1
      Page.count(:conditions => "status_cd = '01'").should == 1
    end


    it "validation error" do
      p1 = Page.create(:name => "top page")
      p1.should_receive(:make_editable)
      p1.name = nil
      Page.should_receive(:find).with(:first, :lock => true,
        :conditions => ["status_cd = ?", '00'], :order => "id asc").and_return(p1)
      lambda{
        Page.process_state(:status_cd, :created)
      }.should raise_error(ActiveRecord::RecordInvalid)

      Page.count.should == 1
      Page.count(:conditions => "status_cd = '00'").should == 1
      Page.count(:conditions => "status_cd = '01'").should == 0
      StateFlow::Log.count.should == 1
      log = StateFlow::Log.first
      log.target_type.should == 'Page'
      log.target_id.should == p1.id
      log.origin_state.should == '00'
      log.origin_state_key.should == 'created'
      log.dest_state.should == '01'
      log.dest_state_key.should == 'editable'
      log.level.should == 'error'
      log.descriptions.should =~ /^Validation failed: Name can't be blank/
      log.descriptions.should =~ /spec\/page_spec.rb/
    end

  end

  describe ":editable => event(:apply) => :approving" do
    it "valid" do
      p1 = Page.create(:name => "top page", :status_cd => Page.status_id_by_key(:editable))
      p1.apply
      p1.reload
      p1.status_key.should == :approving
      StateFlow::Log.count.should == 0
    end

    it "validation error" do
      p1 = Page.create(:name => "top page", :status_cd => Page.status_id_by_key(:editable))
      p1.name = nil
      lambda{
        p1.apply
      }.should raise_error(ActiveRecord::RecordInvalid)
      p1.reload
      p1.status_key.should == :editable
      #
      StateFlow::Log.count.should == 1
      log = StateFlow::Log.first
      log.target_type.should == 'Page'
      log.target_id.should == p1.id
      log.origin_state.should == '01'
      log.origin_state_key.should == 'editable'
      log.dest_state.should == '02'
      log.dest_state_key.should == 'approving'
      log.level.should == 'error'
      log.descriptions.should =~ /^Validation failed: Name can't be blank/
      log.descriptions.should =~ /spec\/page_spec.rb/
    end

  end

  describe ":approving => event(:approve) => :approved" do
    it "valid" do
      p1 = Page.create(:name => "top page", :status_cd => Page.status_id_by_key(:approving))
      p1.approve
      p1.reload
      p1.status_key.should == :approved
      StateFlow::Log.count.should == 0
    end

    it "validation error" do
      p1 = Page.create(:name => "top page", :status_cd => Page.status_id_by_key(:approving))
      p1.name = nil
      lambda{
        p1.approve
      }.should raise_error(ActiveRecord::RecordInvalid)
      p1.reload
      p1.status_key.should == :approving
      #
      StateFlow::Log.count.should == 1
      log = StateFlow::Log.first
      log.target_type.should == 'Page'
      log.target_id.should == p1.id
      log.origin_state.should == '02'
      log.origin_state_key.should == 'approving'
      log.dest_state.should == '03'
      log.dest_state_key.should == 'approved'
      log.level.should == 'error'
      log.descriptions.should =~ /^Validation failed: Name can't be blank/
      log.descriptions.should =~ /spec\/page_spec.rb/
    end
  end

  describe ":approving => event(:reject) => :editable" do
    it "valid" do
      p1 = Page.create(:name => "top page", :status_cd => Page.status_id_by_key(:approving))
      p1.reject
      p1.reload
      p1.status_key.should == :editable
      StateFlow::Log.count.should == 0
    end

    it "validation error" do
      p1 = Page.create(:name => "top page", :status_cd => Page.status_id_by_key(:approving))
      p1.name = nil
      lambda{
        p1.reject
      }.should raise_error(ActiveRecord::RecordInvalid)
      p1.reload
      p1.status_key.should == :approving
      #
      StateFlow::Log.count.should == 1
      log = StateFlow::Log.first
      log.target_type.should == 'Page'
      log.target_id.should == p1.id
      log.origin_state.should == '02'
      log.origin_state_key.should == 'approving'
      log.dest_state.should == '01'
      log.dest_state_key.should == 'editable'
      log.level.should == 'error'
      log.descriptions.should =~ /^Validation failed: Name can't be blank/
      log.descriptions.should =~ /spec\/page_spec.rb/
    end
  end

  describe ":approved => event(:publish) => :waiting_publish" do
    it "valid" do
      p1 = Page.create(:name => "top page", :status_cd => Page.status_id_by_key(:approved))
      p1.publish
      p1.reload
      p1.status_key.should == :waiting_publish
      StateFlow::Log.count.should == 0
    end

    it "validation error" do
      p1 = Page.create(:name => "top page", :status_cd => Page.status_id_by_key(:approved))
      p1.name = nil
      lambda{
        p1.publish
      }.should raise_error(ActiveRecord::RecordInvalid)
      p1.reload
      p1.status_key.should == :approved
      #
      StateFlow::Log.count.should == 1
      log = StateFlow::Log.first
      log.target_type.should == 'Page'
      log.target_id.should == p1.id
      log.origin_state.should == '03'
      log.origin_state_key.should == 'approved'
      log.dest_state.should == '04'
      log.dest_state_key.should == 'waiting_publish'
      log.level.should == 'error'
      log.descriptions.should =~ /^Validation failed: Name can't be blank/
      log.descriptions.should =~ /spec\/page_spec.rb/
    end
  end

  describe ":waiting_publish => :publishing" do
    it "valid" do
      p1 = Page.create(:name => "top page", :status_cd => Page.status_id_by_key(:waiting_publish))
      Page.process_state(:status_cd, :waiting_publish)
      #
      Page.count.should == 1
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:waiting_publish)]).should == 0
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:publishing)]).should == 1
    end

    it "validation error" do
      p1 = Page.create(:name => "top page", :status_cd => Page.status_id_by_key(:waiting_publish))
      p1_backup = p1.clone
      p1.name = nil
      Page.should_receive(:find).with(:first, :lock => true,
        :conditions => ["status_cd = ?", Page.status_id_by_key(:waiting_publish)], :order => "id asc").and_return(p1)
      Page.should_receive(:find).with(p1.id).and_return(p1_backup)
      lambda{
        Page.process_state(:status_cd, :waiting_publish)
      }.should raise_error(ActiveRecord::RecordInvalid)
      Page.count.should == 1
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:waiting_publish)]).should == 0
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:publishing)]).should == 0
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:publish_failure)]).should == 1
      StateFlow::Log.count.should == 1
      log = StateFlow::Log.first
      log.target_type.should == 'Page'
      log.target_id.should == p1.id
      log.origin_state.should == '04'
      log.origin_state_key.should == 'waiting_publish'
      log.dest_state.should == '05'
      log.dest_state_key.should == 'publishing'
      log.level.should == 'error'
      log.descriptions.should =~ /^Validation failed: Name can't be blank/
      log.descriptions.should =~ /spec\/page_spec.rb/
    end

  end


  describe ":waiting_publish => :publishing" do
    it "valid" do
      p1 = Page.create(:name => "top page", :status_cd => Page.status_id_by_key(:waiting_publish))
      Page.process_state(:status_cd, :waiting_publish)
      #
      Page.count.should == 1
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:waiting_publish)]).should == 0
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:publishing)]).should == 1
    end

    it "validation error" do
      p1 = Page.create(:name => "top page", :status_cd => Page.status_id_by_key(:waiting_publish))
      p1_backup = p1.clone
      p1.name = nil
      Page.should_receive(:find).with(:first, :lock => true,
        :conditions => ["status_cd = ?", Page.status_id_by_key(:waiting_publish)], :order => "id asc").and_return(p1)
      # ステータス変更時のsave!で発生する例外による失敗によって対象となるレコードのキーを
      # :failureで指定された:publish_failureに設定して保存するため、
      # バリデーションエラーのないデータをid指定でfindするためここでモックを指定します。
      Page.should_receive(:find).with(p1.id).and_return(p1_backup)
      lambda{
        Page.process_state(:status_cd, :waiting_publish)
      }.should raise_error(ActiveRecord::RecordInvalid)
      Page.count.should == 1
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:waiting_publish)]).should == 0
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:publishing)]).should == 0
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:publish_failure)]).should == 1
      StateFlow::Log.count.should == 1
      log = StateFlow::Log.first
      log.target_type.should == 'Page'
      log.target_id.should == p1.id
      log.origin_state.should == '04'
      log.origin_state_key.should == 'waiting_publish'
      log.dest_state.should == '05'
      log.dest_state_key.should == 'publishing'
      log.level.should == 'error'
      log.descriptions.should =~ /^Validation failed: Name can't be blank/
      log.descriptions.should =~ /spec\/page_spec.rb/
    end

  end


  describe ":publishing => action(:start_publish)" do
    it "valid" do
      p1 = Page.create(:name => "top page", :status_cd => Page.status_id_by_key(:publishing))
      Page.process_state(:status_cd, :publishing)
      # Page.process_stateによって:start_publishが実行されて、そのメソッド内部でステータスが変更されます。
      Page.count.should == 1
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:publishing)]).should == 0
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:publishing_done)]).should == 1
    end

    it "validation error" do
      Page.logger.debug("*" * 100)
      p1 = Page.create(:name => "top page", :status_cd => Page.status_id_by_key(:publishing))
      p1_backup = Page.find(p1.id)
      p1.name = nil
      p1.valid?.should == false
      Page.should_receive(:find).with(:first,
        :conditions => ["status_cd = ?", Page.status_id_by_key(:publishing)], :order => "id asc").and_return(p1)
      Page.should_receive(:find).with(p1.id).and_return(p1_backup)
      
      lambda{
        Page.process_state(:status_cd, :publishing)
      }.should raise_error(ActiveRecord::RecordInvalid)
      Page.count.should == 1
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:publishing)]).should == 0
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:publishing_done)]).should == 0
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:publish_failure)]).should == 1
      StateFlow::Log.count.should == 1
      log = StateFlow::Log.first
      log.target_type.should == 'Page'
      log.target_id.should == p1.id
      log.origin_state.should == '05'
      log.origin_state_key.should == 'publishing'
      log.dest_state.should == nil # '06' # メソッド内で指定しているのでnil
      log.dest_state_key.should == nil # 'publishing_done' # メソッド内で指定しているのでnil
      log.level.should == 'error'
      log.descriptions.should =~ /^Validation failed: Name can't be blank/
      log.descriptions.should =~ /spec\/page_spec.rb/
    end
  end
  

  describe ":publishing_done => :published, :if => :accessable?" do
    it "valid" do
      p1 = Page.create(:name => "published top page", :status_cd => Page.status_id_by_key(:publishing_done))
      Page.process_state(:status_cd, :publishing_done)
      # Page.process_stateによってaccessable?が実行されて、
      # trueならステータス変更されます。このケースではtrueを返します。
      Page.count.should == 1
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:publishing_done)]).should == 0
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:published)]).should == 1
      StateFlow::Log.count.should == 0
    end

    it "do nothing" do
      p1 = Page.create(:name => "closed top page", :status_cd => Page.status_id_by_key(:publishing_done))
      Page.process_state(:status_cd, :publishing_done)
      # Page.process_stateによってaccessable?が実行されて、
      # trueならステータス変更されます。このケースではfalseを返すので何も実行しません。
      Page.count.should == 1
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:publishing_done)]).should == 1
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:published)]).should == 0
      StateFlow::Log.count.should == 0
    end

    it "validation error" do
      Page.logger.debug("*" * 100)
      p1 = Page.create(:name => "top page", :status_cd => Page.status_id_by_key(:publishing))
      p1_backup = Page.find(p1.id)
      p1.name = nil
      p1.valid?.should == false
      Page.should_receive(:find).with(:first,
        :conditions => ["status_cd = ?", Page.status_id_by_key(:publishing)], :order => "id asc").and_return(p1)
      Page.should_receive(:find).with(p1.id).and_return(p1_backup)
      
      lambda{
        Page.process_state(:status_cd, :publishing)
      }.should raise_error(ActiveRecord::RecordInvalid)
      Page.count.should == 1
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:publishing)]).should == 0
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:publishing_done)]).should == 0
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:publish_failure)]).should == 1
      StateFlow::Log.count.should == 1
      log = StateFlow::Log.first
      log.target_type.should == 'Page'
      log.target_id.should == p1.id
      log.origin_state.should == '05'
      log.origin_state_key.should == 'publishing'
      log.dest_state.should == nil # '06' # メソッド内で指定しているのでnil
      log.dest_state_key.should == nil # 'publishing_done' # メソッド内で指定しているのでnil
      log.level.should == 'error'
      log.descriptions.should =~ /^Validation failed: Name can't be blank/
      log.descriptions.should =~ /spec\/page_spec.rb/
    end
  end
  
end
