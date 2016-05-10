# Communication Layer Configuration

module Yast
  class CommunicationConfiguration < BaseComponentConfiguration
    def initialize
      @number_of_rings = 2
      @rings = {}
      init_rings
    end

    def init_rings
      (1..@number_of_rings).each do |i|
        @rings["ring#{i}".to_sym] = {
          address: nil,
          port: nil
        }
      end
    end

    def table_items
    end
  end
end