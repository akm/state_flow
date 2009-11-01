# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), 'spec_helper')

describe Order do
  before(:each) do
    StateFlow::Log.delete_all
    Order.delete_all
  end
  
  

end
