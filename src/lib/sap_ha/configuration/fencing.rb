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
require_relative 'base_config'
Yast.import 'UI'

module SapHA
  module Configuration
    # Fencing configuration
    class Fencing < BaseConfig
      attr_reader :proposals, :sysconfig
      attr_accessor :sbd_options, :sbd_delayed_start
      include Yast::UIShortcuts

      def initialize
        super
        @screen_name = "Fencing Mechanism"
        @devices = []
        @proposals = []
        @sbd_options = "-W"
        @sbd_delayed_start = ""
        @sysconfig = {}
        read_system
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
          device: Yast::SCR.Read(Yast::Path.new('.sysconfig.sbd.SBD_DEVICE')),
          pacemaker: Yast::SCR.Read(Yast::Path.new('.sysconfig.sbd.SBD_PACEMAKER')),
          startmode: Yast::SCR.Read(Yast::Path.new('.sysconfig.sbd.SBD_STARTMODE')),
          delay_start: Yast::SCR.Read(Yast::Path.new('.sysconfig.sbd.SBD_DELAY_START')),
          watchdog: Yast::SCR.Read(Yast::Path.new('.sysconfig.sbd.SBD_WATCHDOG')),
          options: Yast::SCR.Read(Yast::Path.new('.sysconfig.sbd.SBD_OPTS'))
        }
        true
      end

      def write_sysconfig
        devices = @devices.map { |e| e[:name] }.join(';')
        Yast::SCR.Write(Yast::Path.new('.sysconfig.sbd.SBD_DEVICE'), devices)
        Yast::SCR.Write(Yast::Path.new('.sysconfig.sbd.SBD_PACEMAKER'), "yes")
        Yast::SCR.Write(Yast::Path.new('.sysconfig.sbd.SBD_STARTMODE'), "always")
        Yast::SCR.Write(Yast::Path.new('.sysconfig.sbd.SBD_DELAY_START'), @sbd_delayed_start)
        Yast::SCR.Write(Yast::Path.new('.sysconfig.sbd.SBD_WATCHDOG'), "yes")
        Yast::SCR.Write(Yast::Path.new('.sysconfig.sbd.SBD_OPTS'), @sbd_options)
        commit = Yast::SCR.Write(Yast::Path.new('.sysconfig.sbd'), nil)
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
        flag &= SapHA::System::Local.initialize_sbd(@devices) if role == :master
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
        @proposals = SapHA::System::Local.block_devices
      end
    end
  end
end
