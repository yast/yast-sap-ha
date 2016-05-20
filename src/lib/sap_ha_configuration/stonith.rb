require 'yast'
require_relative 'base_component_configuration.rb'
Yast.import 'UI'

module Yast
  class StonithConfiguration < BaseComponentConfiguration
    attr_reader :proposals

    include Yast::UIShortcuts

    def initialize
      @devices = []
      @proposals = refresh_proposals
    end

    def configured?
      @devices.length > 0
    end

    def description
      ds = @devices.map { |d| d[:name] }.join(', ')
      "&nbsp; Configured devices: #{ds}."
    end

    def combo_items
      @proposals.map { |e| e[:name] }
    end

    def table_items
      @devices.each_with_index.map { |e, i| Item(Id(i), i.to_s, e[:name], e[:type], e[:uuid]) }
    end

    def add_to_config(dev_path)
      @devices << @proposals.find { |e| e[:name] == dev_path }.dup
    end

    def rm_from_config(dev_path)
      # TODO
    end

    private

    def refresh_proposals
      `lsblk -pnio KNAME,TYPE,LABEL,UUID`.split("\n").map do |s| 
        Hash[[:name, :type, :uuid].zip(s.split)]
      end.select { |d| d[:type] == "part" || d[:type] == "disk" }
    end
  end
end