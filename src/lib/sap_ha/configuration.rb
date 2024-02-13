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
# Summary: SUSE High Availability Setup for SAP Products: Top-level configuration
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require "yast"
require "erb"
require "psych"

require "sap_ha/helpers"
require "sap_ha/node_logger"
require "sap_ha/configuration/cluster"
require "sap_ha/configuration/fencing"
require "sap_ha/configuration/watchdog"
require "sap_ha/configuration/hana"
require "sap_ha/configuration/ntp"
require "sap_ha/system/local"
require "sap_ha/system/shell_commands"

module SapHA
  # Module's configuration
  class HAConfiguration
    attr_reader :product_id,
      :scenario_name,
      :config_sequence,
      :scenario,
      :product_name,
      :product,
      :scenario_summary,
      :timestamp
    attr_accessor :role,
      :debug,
      :no_validators,
      :cluster,
      :fencing,
      :watchdog,
      :hana,
      :ntp,
      :imported,
      :unattended,
      :completed,
      :platform

    include Yast::Logger
    include Yast::I18n
    include SapHA::Exceptions
    include SapHA::System::ShellCommands

    def initialize(role = :master)
      @timestamp = Time.now
      @imported = false
      @unattended = false
      @completed = false
      @role = role
      @debug = false
      @no_validators = false
      @product_id = nil
      @product_name = nil
      @product = nil
      @scenario_name = nil
      @scenario = nil
      @scenario_summary = nil
      @yaml_configuration = load_scenarios
      @cluster = Configuration::Cluster.new(self)
      @fencing = Configuration::Fencing.new(self)
      @watchdog = Configuration::Watchdog.new(self)
      @hana = Configuration::HANA.new(self)
      @ntp = Configuration::NTP.new(self)
      @config_sequence = []
      @platform = SapHA::Helpers.platform_check
      @fw_state = exec_status("/usr/bin/firewall-cmd","--state").exitstatus
    end

    # Function to refresh the proposals of some modules. This is neccessary when
    # loading an old configuration to detect new hardware.
    def refresh_all_proposals
      @watchdog.refresh_proposals
      @fencing.refresh_proposals
    end

    # Product ID setter. Raises an ScenarioNotFoundException if the ID was not found
    # @param [String] value product ID
    def set_product_id(value)
      log.debug "--- called #{self.class}.#{__callee__}(#{value}) ---"
      @product_id = value
      product = @yaml_configuration.find do |p|
        p.fetch("id", "") == @product_id
      end
      raise ProductNotFoundException, "Could not find product with ID '#{value}'" unless product
      @product = product.dup
      @product_name = @product["string_name"]
    end

    # Scenario Name setter. Raises an ScenarioNotFoundException if the name was not found
    # @param [String] value scenario name
    def set_scenario_name(value)
      log.debug "--- called #{self.class}.#{__callee__}(#{value}) ---"
      log.info "Selected scenario is '#{value}' for product '#{@product_name}'"
      raise ProductNotFoundException,
        "Setting scenario name before setting the Product ID" if @product.nil?
      @scenario_name = value
      @scenario = @product["scenarios"].find { |s| s["name"] == @scenario_name }
      unless @scenario
        log.error("Scenario name '#{@scenario_name}' not found in the scenario list")
        raise ScenarioNotFoundException
      end
      apply_scenario
    end

    def apply_scenario
      log.debug "--- called #{self.class}.#{__callee__}() ---"
      if @scenario["config_sequence"]
        @config_sequence = @scenario["config_sequence"].map do |el|
          instv = "@#{el}".to_sym
          unless instance_variable_defined?(instv)
            log.error "Scenario #{@scenario} requires a configuration object"\
              " #{el} which is not defined."
            raise GUIFatal, "Scenario configuration is incorrect. Please check the logs."
          end
          { id:          el,
            var_name:    instv,
            object:      instance_variable_get(instv), # local configuration object
            screen_name: instance_variable_get(instv).screen_name, # screen name for GUI
            rpc_object:  "sapha.config_#{el}",
            rpc_method:  "sapha.config_#{el}.apply" }
        end
      else
        log.error "Scenario #{@scenario} does not set a configuration sequence."
        raise GUIFatal, "Scenario configuration is incorrect. Please check the logs."
      end
      @cluster.set_fixed_nodes(
        @scenario.fetch("fixed_number_of_nodes", false),
        @scenario.fetch("number_of_nodes", 2)
      )
      @hana.additional_instance = @scenario["additional_instance"] || false if @hana
    end

    def all_scenarios
      log.debug "--- called #{self.class}.#{__callee__}() ---"
      raise ProductNotFoundException,
        "Getting scenarios list before setting the Product ID" if @product.nil?
      @product["scenarios"].map { |s| s["name"] }
    end

    # Generate help string for all scenarios
    def scenarios_help
      log.debug "--- called #{self.class}.#{__callee__}() ---"
      raise ProductNotFoundException,
        "Getting scenarios help before setting the Product ID" if @product.nil?
      (@product["scenarios"].map { |s| s["description"] }).join("<br><br>")
    end

    # Can the cluster be set up?
    def can_install?
      log.debug "--- called #{self.class}.#{__callee__}() ---"
      return false if @config_sequence.empty?
      @config_sequence.map do |config|
        flag = config[:object].configured?
        unless flag
          log.warn "Component #{config[:screen_name]} is not configured:" unless flag
          config[:object].validate(:verbose).each { |e| log.warn e }
        end
        flag
      end.all?
    end

    def verbose_validate
      log.debug "--- called #{self.class}.#{__callee__}() ---"
      return ["Configuration sequence is empty"] if @config_sequence.empty?
      @config_sequence.map do |config|
        config[:object].validate
      end.flatten
    end

    # Dump this object to a YAML representation
    # @param [Boolean] slave
    def dump(slave = false, force = false)
      log.debug "--- called #{self.class}.#{__callee__}(#{slave}, #{force}) ---"
      return unless can_install? || force
      # TODO: the proposals are also kept in this way of duplicating...
      old_role = @role
      @role = :slave if slave
      repr = Psych.dump self
      @role = old_role
      repr
    end

    # Below are the methods for logging the setup process
    def start_setup
      log.debug "--- called #{self.class}.#{__callee__} ---"
      @timestamp = Time.now
      NodeLogger.info( "Starting setup process on node #{SapHA::NodeLogger.node_name}")
      true
    end

    def end_setup
      log.debug "--- called #{self.class}.#{__callee__} ---"
      NodeLogger.info( "Finished setup process on node #{SapHA::NodeLogger.node_name}")
      # Start firewall if this was running by starting the module on slave nodes
      if @fw_state == 0
        if @role == :master
	  SapHA::Helpers.write_var_file("need_to_start_firewalld","")
	else
          SapHA::System::Local.systemd_unit(:stop, :service, "firewalld")
	end
      end
      true
    end

    def collect_log
      log.debug "--- called #{self.class}.#{__callee__} ---"
      NodeLogger.text
    end

    def write_config
      log.debug "--- called #{self.class}.#{__callee__} ---"
      @timestamp = Time.now
      SapHA::Helpers.write_var_file("configuration.yml", dump(false, true), timestamp: @timestamp)
    end

  private

    # Load scenarios from the YAML configuration file
    def load_scenarios
      log.debug "--- called #{self.class}.#{__callee__} ---"
      begin
        Psych.unsafe_load_file(SapHA::Helpers.data_file_path("scenarios.yaml"))
      rescue NoMethodError
        Psych.load_file(SapHA::Helpers.data_file_path("scenarios.yaml"))
      end
    end
  end # class Configuration
end # module Yast
