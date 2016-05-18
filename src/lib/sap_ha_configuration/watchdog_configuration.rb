require 'yast'
# require 'sap_ha_system/watchdog'
require_relative '../sap_ha_system/watchdog.rb'
require_relative 'base_component_configuration.rb'
# Yast.import 'UI'

module Yast
  class WatchdogConfiguration < BaseComponentConfiguration
    
    attr_reader :installed, :proposals, :loaded

    include Yast::UIShortcuts

    def initialize
      @system = Watchdog.instance
      @loaded = @system.loaded_watchdogs
      @installed = @system.installed_watchdogs
      @to_install = []
      @proposals = @system.list_watchdogs
    end

    def configured?
      !@loaded.empty? || !@installed.empty? || !@to_install.empty?
    end

    def description
      s = []
      unless @installed.empty?
        wd = @installed.join(', ')
        s << "Configured modules: #{wd}."
      end
      unless @loaded.empty?
        wd = @loaded.join(', ')
        s << "Already loaded modules: #{wd}."
      end
      unless @to_install.empty?
        wd = @to_install.join(', ')
        s << "Modules to install: #{wd}."
      end
      return '' if s.empty?
      s.join('<br>')
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