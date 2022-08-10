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
# Summary: SUSE High Availability Setup for SAP Products: System watchdog configuration
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'open3'
require_relative 'shell_commands'
require 'sap_ha/node_logger'

Yast.import 'Kernel'

module SapHA
  module System
    class WatchdogException < Exception
    end

    # System watchdog configuration
    class WatchdogClass
      include Singleton
      include Yast::Logger
      include ShellCommands

      MODULES_PATH = "/lib/modules/#{`uname -r`.strip}/kernel/drivers/watchdog".freeze

      # Add the watchdog with the given name to the /etc/modules-load.d
      # @param module_name [String]
      # @return [Boolean]
      def install(module_name)
        if installed?(module_name)
          NodeLogger.info("Watchdog module #{module_name} is already installed")
          return true
        end
        unless watchdog? module_name
          NodeLogger.error("Cannot install a watchdog module #{module_name}")
          return false
        end
        Yast::Kernel.AddModuleToLoad(module_name)
        stat = Yast::Kernel.SaveModulesToLoad
        NodeLogger.info("Installed watchdog module #{module_name}") if stat
      end

      # Check if any of the known watchdogs are loaded into the current kernel
      # @return [Boolean]
      def any_loaded?
        !loaded_watchdogs.empty?
      end

      # Check if the watchdog with the given name is loaded into the current kernel
      # @param module_name [String]
      # @return [Boolean]
      def loaded?(module_name)
        !([module_name] & lsmod).empty?
      end

      # List all watchdog modules loaded into the current kernel
      def loaded_watchdogs
        list_watchdogs & lsmod
      end

      # Check if any of the known watchdogs are added to the /etc/modules-load.d
      def watchdog_installed?
        !installed_watchdogs.empty?
      end

      # Check if the watchdog with the given name is added to the /etc/modules-load.d
      # @param module_name [String]
      # @return [Boolean]
      def installed?(module_name)
        if watchdog? module_name
          !([module_name] & modules_to_load).empty?
        else
          false
        end
      end

      # Check if the given kernel module a known watchdog module
      # @param module_name [String]
      # @return [Boolean]
      def watchdog?(module_name)
        if ([module_name] & list_watchdogs).empty?
          log.error "Module '#{module_name}' is not a watchdog!"
          return false
        end
        true
      end

      # List all watchdog modules from the /etc/modules-load.d
      def installed_watchdogs
        list_watchdogs & modules_to_load
      end

      # Get the list of all watchdog available in the system
      def list_watchdogs
        unless Dir.exist?(MODULES_PATH)
          log.error "Could not find the kernel modules source directory #{MODULES_PATH}"
          return []
        end
        wmods = Dir.glob(MODULES_PATH + '/*.ko*').map { |path| File.basename(path).gsub(/\.ko[\.\S+]*$/,'') }
        wmods
      end

      # Look into the /etc/modules-load.d and list all of the modules
      def modules_to_load
        mods = []
        Yast::Kernel.modules_to_load.each { |_, v| mods.concat(v) }
        mods
      end

      def load(module_name)
        out, rc = exec_outerr_status('/usr/sbin/modprobe', module_name)
        NodeLogger.log_status(rc.exitstatus == 0,
          "Loaded watchdog module #{module_name}",
          "Could not load module #{module_name}. modprobe returned rc=#{rc.exitstatus}",
          out)
      end

      private

      def lsmod
        Open3.popen3("/usr/sbin/lsmod") do |_, stdout, _, _|
          stdout.map { |l| l.split[0] }[1..-1]
        end
      end
    end # class
    Watchdog = WatchdogClass.instance
  end # module
end # module
