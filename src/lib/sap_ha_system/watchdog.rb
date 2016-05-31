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
Yast.import 'Kernel'

module Yast
  class WatchdogException < Exception
  end

  # System watchdog configuration
  class Watchdog
    include Singleton
    include Yast::Logger
    include ShellCommands
        
    MODULES_PATH = '/usr/src/linux/drivers/watchdog'.freeze

    # Add the watchdog with the given name to the /etc/modules-load.d
    # @param watchdog [String]
    # @return [Boolean]
    def install(watchdog)
      return true if installed?(watchdog)
      return false unless can_install?(watchdog)
      Kernel.AddModuleToLoad(watchdog)
      true
    end

    # Check if any of the known watchdogs are loaded into the current kernel
    # @return [Boolean]
    def any_loaded?
      !loaded_watchdogs.empty?
    end

    # Check if the watchdog with the given name is loaded into the current kernel
    # @param watchdog [String]
    # @return [Boolean]
    def loaded?(watchdog)
      !([watchdog] & lsmod).empty?
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
    # @param watchdog [String]
    # @return [Boolean]
    def installed?(watchdog)
      if can_install? watchdog
        !([watchdog] & modules_to_load).empty?
      else
        false
      end
    end

    # Check if the given kernel module a known watchdog module
    # @param watchdog [String]
    # @return [Boolean]
    def watchdog?(watchdog)
      if ([watchdog] & list_watchdogs).empty?
        log.error "Cannot install module '#{watchdog}': this is not a watchdog!"
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
        log.error "Could not find the modules source directory #{MODULES_PATH}"
        raise "Could not find the modules source directory #{MODULES_PATH}"
      end
      Dir.glob(MODULES_PATH + '/*.c').map { |path| File.basename(path, '.c') }
    end

    # Look into the /etc/modules-load.d and list all of the modules
    def modules_to_load
      mods = []
      Kernel.modules_to_load.each { |_, v| mods.concat(v) }
      mods
    end

    def load(module_name)
      rc = exec_status_l('/usr/sbin/modprobe', module_name)
      unless rc.exitstatus == 0
        log.error "Could not load module #{module_name}. modprobe returned rc=#{rc}"
        raise WatchdogException, "Could not load module #{module_name}."
      end
    end
  
    private

    def lsmod
      Open3.popen3("lsmod") do |_, stdout, _, _|
        stdout.map { |l| l.split[0] }[1..-1]
      end
    end
  end # class
end # module
