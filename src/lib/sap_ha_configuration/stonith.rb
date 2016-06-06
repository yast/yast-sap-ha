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
    attr_reader :proposals, :sysconfig
    attr_accessor :sbd_options, :sbd_delayed_start

    include Yast::UIShortcuts

    def initialize
      super
      @screen_name = "Fencing Mechanism"
      @devices = []
      @proposals = []
      @sbd_options = ""
      @sbd_delayed_start = ""
      @sysconfig = {}
    end

    def read_system
      refresh_proposals
      read_sysconfig
      handle_sysconfig
    end

    def configured?
      !@devices.empty?
    end

    def description
      ds = @devices.map { |d| d[:name] }.join(', ')
      "&nbsp; Configured devices: #{ds}.<br>
      &nbsp; Delayed start : #{@sysconfig[:dealy_start]}<br>
      &nbsp; SBD options : #{@sysconfig[:options]}"
    end

    # Drop-down box items
    def combo_items
      @proposals.map { |e| e[:name] }
    end

    def table_items
      @devices.each_with_index.map { |e, i| Item(Id(i), i.to_s, e[:name], e[:type], e[:uuid]) }
    end

    def add_device(dev_path)
      @devices << @proposals.find { |e| e[:name] == dev_path }.dup
    end

    def remove_device(dev_path)
      @devices.delete_if { |e| e[:name] == dev_path }
    end

    def remove_device_by_id(dev_id)
      dev = @devices.each_with_index.find { |e, ix| ix == dev_id }
      return if dev.empty?
      log.error "--- called #{self.class}.#{__callee__} dev=#{dev} ---"
      rm_from_config(dev[0][:name])
    end

    def read_sysconfig
      @sysconfig = {
        device: SCR.Read(Path.new('.sysconfig.sbd.SBD_DEVICE')),
        pacemaker: SCR.Read(Path.new('.sysconfig.sbd.SBD_PACEMAKER')),
        startmode: SCR.Read(Path.new('.sysconfig.sbd.SBD_STARTMODE')),
        delay_start: SCR.Read(Path.new('.sysconfig.sbd.SBD_DELAY_START')),
        watchdog: SCR.Read(Path.new('.sysconfig.sbd.SBD_WATCHDOG')),
        options: SCR.Read(Path.new('.sysconfig.sbd.SBD_OPTS'))
      }
      true
    end

    def write_sysconfig
      # always should be here
      devices = @devices.map { |e| e[:name] }.join(';')
      SCR.Write(Path.new('.sysconfig.sbd.SBD_DEVICE'), devices)
      SCR.Write(Path.new('.sysconfig.sbd.SBD_PACEMAKER'), "yes")
      SCR.Write(Path.new('.sysconfig.sbd.SBD_STARTMODE'), "always")
      SCR.Write(Path.new('.sysconfig.sbd.SBD_DELAY_START'), @sbd_delayed_start)
      SCR.Write(Path.new('.sysconfig.sbd.SBD_WATCHDOG'), "yes")
      SCR.Write(Path.new('.sysconfig.sbd.SBD_OPTS'), @sbd_options)
      SCR.Write(Path.new('.sysconfig.sbd'), nil)
    end

    private

    def handle_sysconfig
      devices = @sysconfig[:device].split(";")
      @devices = devices.map { |d| @proposals.find { |p| p[:name] == d } }.compact
      @sbd_options = @sysconfig[:options] || ""
      @sbd_delayed_start = @sysconfig[:delay_start] || "no"
      true
    end

    def refresh_proposals
      # TODO: move to the ShellCommands
      blk = `lsblk -pnio KNAME,TYPE,LABEL,UUID`.split("\n").map do |s|
        Hash[[:name, :type, :uuid].zip(s.split)]
      end
      @proposals = blk.select { |d| d[:type] == "part" || d[:type] == "disk" }
    end

    def apply(role)
      return false if !configured?
      write_sysconfig
    end
  end
end
