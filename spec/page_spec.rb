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
      log.origin_state == '00'
      log.origin_state_key == ':created'
      log.dest_state == '01'
      log.dest_state_key == ':editable'
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
      log.origin_state == '01'
      log.origin_state_key == ':editable'
      log.dest_state == '02'
      log.dest_state_key == ':approving'
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
      log.origin_state == '01'
      log.origin_state_key == ':approving'
      log.dest_state == '02'
      log.dest_state_key == ':approved'
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
      log.origin_state == '01'
      log.origin_state_key == ':approving'
      log.dest_state == '02'
      log.dest_state_key == ':editable'
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
      log.origin_state == '01'
      log.origin_state_key == ':approved'
      log.dest_state == '02'
      log.dest_state_key == ':waiting_publish'
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
      p1.name = nil
      Page.should_receive(:find).with(:first, :lock => true,
        :conditions => ["status_cd = ?", Page.status_id_by_key(:waiting_publish)], :order => "id asc").and_return(p1)
      lambda{
        Page.process_state(:status_cd, :waiting_publish)
      }.should raise_error(ActiveRecord::RecordInvalid)

      Page.count.should == 1
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:waiting_publish)]).should == 1
      Page.count(:conditions => ["status_cd = ?", Page.status_id_by_key(:publishing)]).should == 0
      StateFlow::Log.count.should == 1
      log = StateFlow::Log.first
      log.target_type.should == 'Page'
      log.target_id.should == p1.id
      log.origin_state == '00'
      log.origin_state_key == ':waiting_publish'
      log.dest_state == '01'
      log.dest_state_key == ':publishing'
      log.level.should == 'error'
      log.descriptions.should =~ /^Validation failed: Name can't be blank/
      log.descriptions.should =~ /spec\/page_spec.rb/
    end

  end
end
