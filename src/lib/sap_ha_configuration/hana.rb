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
# Summary: SUSE High Availability Setup for SAP Products: HANA configuration
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'sap_ha_system/watchdog'
require_relative 'base_component_configuration.rb'

module Yast
  # HANA configuration
  class HANAConfiguration < BaseComponentConfiguration
    
    attr_accessor :system_id,
      :instance,
      :virtual_ip,
      :prefer_takeover,
      :auto_register

    include Yast::UIShortcuts

    def initialize
      super
      @screen_name = "HANA Configuration"
      @system_id = 'NDB' # TODO
      @instance = '00'
      @virtual_ip = ''
      @prefer_takeover = true
      @auto_register = false
    end

    def configured?
      # TODO: HANA validators
      !@virtual_ip.empty?
      flag = true
      flag &= SemanticChecks.instance.check(:silent) do |check|
        check.ipv4(@virtual_ip)
        check.integer_in_range(@instance, 0, 99)
        check.sap_sid(@system_id)
      end
    end

    def description
      "&nbsp; System ID: #{@system_id}, Instance: #{@instance}.<br>
      &nbsp; Virtual IP: #{@virtual_ip}.<br>
      &nbsp; Prefer takeover: #{@prefer_takeover}.<br>
      &nbsp; Automatic Registration: #{@auto_register}.
      "
    end

    def add_to_config(wdt_module)
      @to_install << wdt_module
      @installed = @system.installed_watchdogs.concat(@to_install)
    end

    def combo_items
      @proposals
    end

    def apply(role)
      return false if !configured?
    end
  end
end
