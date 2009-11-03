# -*- coding: utf-8 -*-
require 'state_flow'
module StateFlow

  module ElementVisitable
    # Visitorパターン
    def visit(&block)
      results = block.call(self)
      (results || [:events, :guards, :action]).each do |elements_name|
        next if [:events, :guards, :action].include?(elements_name) && !respond_to?(elements_name)
        elements = send(elements_name)
        elements = [elements] unless elements.is_a?(Array)
        elements.each do |element|
          element.visit(&block) if element
        end
      end
    end
  end
end
