# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE Linux GmbH, Nuernberg, Germany.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE Linux GmbH.
#
# ------------------------------------------------------------------------------
#
# Summary: SUSE High Availability Setup for SAP Products: STONITH configuration
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require_relative 'base_component_configuration.rb'
Yast.import 'UI'

module Yast
  # STONITH configuration
  class StonithConfiguration < BaseComponentConfiguration
    attr_reader :proposals

    include Yast::UIShortcuts

    def initialize
      @devices = []
      @proposals = refresh_proposals
    end

    def configured?
      !@devices.empty?
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
      @devices.delete_if { |e| e[:name] == dev_path }
    end

    def rm_from_config_by_id(dev_id)
      dev = @devices.each_with_index.find { |e, ix| ix == dev_id }
      return if dev.empty?
      log.error "--- called #{self.class}.#{__callee__} dev=#{dev} ---"
      rm_from_config(dev[0][:name])
    end

    private

    def refresh_proposals
      # TODO: move to the ShellCommands
      blk = `lsblk -pnio KNAME,TYPE,LABEL,UUID`.split("\n").map do |s|
        Hash[[:name, :type, :uuid].zip(s.split)]
      end
      blk.select { |d| d[:type] == "part" || d[:type] == "disk" }
    end
  end
end
