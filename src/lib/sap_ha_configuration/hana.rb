require 'yast'
# require 'sap_ha_system/watchdog'
require_relative '../sap_ha_system/watchdog.rb'
require_relative 'base_component_configuration.rb'
# Yast.import 'UI'

module Yast
  class HANAConfiguration < BaseComponentConfiguration
    
    attr_accessor :system_id,
                  :instance,
                  :virtual_ip,
                  :prefer_takeover,
                  :auto_register

    include Yast::UIShortcuts

    def initialize
      @system_id = 'NDB' # TODO
      @instance = '00'
      @virtual_ip = ''
      @prefer_takeover = true
      @auto_register = false
    end

    def configured?
      !@virtual_ip.empty?
    end

    def description
      "&nbsp; SID: #{@system_id}, Instance: #{@instance}, vIP: #{@virtual_ip}<br>
      &nbsp; Prefer takeover: #{@prefer_takeover}, Automatic Registration: #{@auto_register}.
      "
    end

    def add_to_config(wdt_module)
      @to_install << wdt_module
      @installed = @system.installed_watchdogs.concat(@to_install)
    end

    def combo_items
      @proposals
    end
  end
end