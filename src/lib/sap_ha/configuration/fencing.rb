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

require "yast"
require_relative "base_config"
Yast.import "UI"

module SapHA
  module Configuration
    # Fencing configuration
    class Fencing < BaseConfig
      attr_reader :proposals, :sysconfig
      attr_accessor :sbd_options, :sbd_delayed_start, :devices
      include Yast::UIShortcuts
      include Yast::Logger

      def initialize(global_config)
        super
        log.debug "--- #{self.class}.#{__callee__} ---"
        @screen_name = "Fencing Mechanism"
        @devices = []
        @proposals = []
        @sbd_options = "-W"
        @sbd_delayed_start = "no"
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

      def validate(verbosity = :verbose)
        if verbosity == :verbose
          return ["Please specify at least one SBD device."] unless configured?
          return []
        else
          return configured?
        end
      end

      def description
        ds = @devices.join(", ")
        options = @sbd_options.empty? ? "none" : @sbd_options
        prepare_description do |dsc|
          dsc.parameter("Configured devices", ds)
          dsc.parameter("Delayed start", @sbd_delayed_start)
          dsc.parameter("SBD options", options)
        end
      end

      # Drop-down box items
      def combo_items
        @proposals.keys.sort
      end

      def list_items(key)
        @proposals[key].keys.sort
      end

      def table_items
        de_items = @devices.each_with_index.map { |e, i| Item(Id(i), (i + 1).to_s, e) }
        log.debug "table_items #{@devices}"
        return de_items
      end

      def popup_validator(check, dev_path)
        check.block_device(dev_path, "Device path")
      end

      def add_device(dev_path)
        # dev_path = @proposals[dev_type][dev_id]
        return if @devices.index(dev_path)
        @devices << dev_path
      end

      def remove_device(dev_path)
        @devices.delete_if { |e| e == dev_path }
      end

      def remove_device_by_id(dev_id)
        dev = @devices.each_with_index.find { |_, ix| ix == dev_id }
        return if dev.nil? || dev.empty?
        log.error "--- called #{self.class}.#{__callee__} dev=#{dev} ---"
        remove_device(dev[0])
      end

      def read_sysconfig
        @sysconfig = {
          device:      Yast::SCR.Read(Yast::Path.new(".sysconfig.sbd.SBD_DEVICE")),
          pacemaker:   Yast::SCR.Read(Yast::Path.new(".sysconfig.sbd.SBD_PACEMAKER")),
          startmode:   Yast::SCR.Read(Yast::Path.new(".sysconfig.sbd.SBD_STARTMODE")),
          delay_start: Yast::SCR.Read(Yast::Path.new(".sysconfig.sbd.SBD_DELAY_START")),
          watchdog:    Yast::SCR.Read(Yast::Path.new(".sysconfig.sbd.SBD_WATCHDOG")),
          options:     Yast::SCR.Read(Yast::Path.new(".sysconfig.sbd.SBD_OPTS"))
        }
        true
      end

      def write_sysconfig
        devices = @devices.join(";")
        Yast::SCR.Write(Yast::Path.new(".sysconfig.sbd.SBD_DEVICE"), devices)
        Yast::SCR.Write(Yast::Path.new(".sysconfig.sbd.SBD_PACEMAKER"), "yes")
        Yast::SCR.Write(Yast::Path.new(".sysconfig.sbd.SBD_STARTMODE"), "always")
        Yast::SCR.Write(Yast::Path.new(".sysconfig.sbd.SBD_DELAY_START"), @sbd_delayed_start)
        Yast::SCR.Write(Yast::Path.new(".sysconfig.sbd.SBD_WATCHDOG"), "yes")
        Yast::SCR.Write(Yast::Path.new(".sysconfig.sbd.SBD_OPTS"), @sbd_options)
        commit = Yast::SCR.Write(Yast::Path.new(".sysconfig.sbd"), nil)
        if commit
          @nlog.info("Wrote SBD system configuration")
        else
          @nlog.warn("Could not write the SBD system configuration")
        end
        commit
      end

      def apply(role)
        @nlog.info("Appying Fencing Configuration")
        return false unless configured?
        flag = write_sysconfig
        flag &= SapHA::System::Local.initialize_sbd(@devices) if role == :master
        flag
      end

      def refresh_proposals
        @proposals = SapHA::System::Local.block_devices
      end

    private
      def handle_sysconfig
        handle = ->(sett, default) { (sett.nil? || sett.empty?) ? default : sett }
        @devices = handle.call(@sysconfig[:device], "").split(";")
        @sbd_options = handle.call(@sysconfig[:options], @sbd_options)
        @sbd_delayed_start = handle.call(@sysconfig[:delay_start], @sbd_delayed_start)
        true
      end

    end
  end
end
