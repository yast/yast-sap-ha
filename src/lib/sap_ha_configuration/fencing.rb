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
# Summary: SUSE High Availability Setup for SAP Products: Fencing configuration
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'sap_ha_system/shell_commands'
require_relative 'base_component_configuration.rb'
Yast.import 'UI'

module Yast
  # Fencing configuration
  class FencingConfiguration < BaseComponentConfiguration
    attr_reader :proposals, :sysconfig
    attr_accessor :sbd_options, :sbd_delayed_start

    include ShellCommands
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
      options = if @sysconfig[:options].nil? || @sysconfig[:options].empty?
                  'none'
                else
                  @sysconfig[:options]
                end
      "&nbsp; Configured devices: #{ds}.<br>
      &nbsp; Delayed start: #{@sysconfig[:dealy_start] || 'false'}.<br>
      &nbsp; SBD options: #{options}."
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
      remove_device(dev[0][:name])
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
      devices = @devices.map { |e| e[:name] }.join(';')
      SCR.Write(Path.new('.sysconfig.sbd.SBD_DEVICE'), devices)
      SCR.Write(Path.new('.sysconfig.sbd.SBD_PACEMAKER'), "yes")
      SCR.Write(Path.new('.sysconfig.sbd.SBD_STARTMODE'), "always")
      SCR.Write(Path.new('.sysconfig.sbd.SBD_DELAY_START'), @sbd_delayed_start)
      SCR.Write(Path.new('.sysconfig.sbd.SBD_WATCHDOG'), "yes")
      SCR.Write(Path.new('.sysconfig.sbd.SBD_OPTS'), @sbd_options)
      commit = SCR.Write(Path.new('.sysconfig.sbd'), nil)
      if commit
        @nlog.info('Written SBD system configuration')
      else
        @nlog.warn('Could not write the SBD system configuration')
      end
      commit
    end

    def apply(role)
      @nlog.info('Appying Fencing Configuration')
      return false if !configured?
      flag = write_sysconfig
      if role == :master
        flag &= initialize_sbd
        flag &= add_stonith_resource
      end
      flag
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

    def initialize_sbd
      flag = true
      for device in @devices
        log.warn "Initializing the SBD device on #{device[:name]}"
        status = exec_status_l('sbd', '-d', device[:name], 'create')
        log.warn "SBD initialization on #{device[:name]} returned #{status.exitstatus}"
        if status.exitstatus == 0
          @nlog.info "Successfully initialized the SBD device #{device[:name]}"
        else
          @nlog.error "Could not initialize the SBD device #{device[:name]}"
        end
        flag &= status.exitstatus == 0
      end
      flag
    end

    def add_stonith_resource
      out, status = exec_outerr_status('crm', 'configure', 'primitive', 'stonith-sbd', 'stonith:external/sbd')
      success = status.exitstatus == 0
      if success
        @nlog.info('Added a primitive to the cluster: stonith-sbd')
      else
        @nlog.error('Could not add the stonith-sbd primitive to the cluster')
        @nlog.error("Output:\n #{out.strip}")
      end
      success
    end
  end
end
