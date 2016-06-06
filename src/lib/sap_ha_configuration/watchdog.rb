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
# Summary: SUSE High Availability Setup for SAP Products: Watchdog configuration
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'sap_ha_system/watchdog'
require_relative 'base_component_configuration.rb'

module Yast
  # Watchdog configuration
  class WatchdogConfiguration < BaseComponentConfiguration
    
    attr_reader :installed, :proposals, :loaded

    include Yast::UIShortcuts

    def initialize
      super
      @screen_name = "Watchdog Setup"
      @loaded = Watchdog.instance.loaded_watchdogs
      @installed = Watchdog.instance.installed_watchdogs
      @to_install = []
      @proposals = Watchdog.instance.list_watchdogs
    end

    def configured?
      !@loaded.empty? || !@installed.empty? || !@to_install.empty?
    end

    def description
      s = []
      s << "&nbsp; Configured modules: #{@installed.join(', ')}." unless @installed.empty?
      s << "&nbsp; Already loaded modules: #{@loaded.join(', ')}." unless @loaded.empty?
      s << "&nbsp; Modules to install: #{@to_install.join(', ')}." unless @to_install.empty?
      return '' if s.empty?
      s.join('<br>')
    end

    def add_to_config(wdt_module)
      @to_install << wdt_module
      @installed = Watchdog.instance.installed_watchdogs.concat(@to_install)
    end

    def remove_from_config(wdt_module)
      return unless @to_install.include? wdt_module
      @to_install -= [wdt_module]
      @installed = Watchdog.instance.installed_watchdogs.concat(@to_install)
    end

    def apply(role)
      return false if !configured?
      true
    end
  end
end
