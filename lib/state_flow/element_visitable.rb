# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  module ElementVisitable
    # Visitorパターン
    def visit(&block)
      results = block.call(self)
      (results || [:events, :guards, :action]).each do |entries_name|
        next if [:events, :guards, :action].include?(entries_name) && !respond_to?(entries_name)
        entries = send(entries_name)
        entries = [entries] unless entries.is_a?(Array)
        entries.each do |element|
          element.visit(&block) if element
        end
      end
    end
  end
end
