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

require 'yast'
require 'erb'
require 'yaml'

require 'sap_ha/helpers'
require 'sap_ha/node_logger'
require 'sap_ha/configuration/cluster'
require 'sap_ha/configuration/fencing'
require 'sap_ha/configuration/watchdog'
require 'sap_ha/configuration/hana'
require 'sap_ha/configuration/ntp'

module SapHA
  # Module's configuration
  class HAConfiguration
    attr_reader :product_id,
      :scenario_name,
      :config_sequence,
      :scenario,
      :product_name,
      :product,
      :scenario_summary
    attr_accessor :role,
      :debug,
      :no_validators,
      :cluster,
      :fencing,
      :watchdog,
      :hana,
      :ntp

    include Yast::Logger
    include Yast::I18n
    include SapHA::Exceptions

    def initialize(role = :master)
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
      @cluster = Configuration::Cluster.new
      @fencing = Configuration::Fencing.new
      @watchdog = Configuration::Watchdog.new
      @hana = Configuration::HANA.new
      @ntp = Configuration::NTP.new
      @config_sequence = []
    end

    # Product ID setter. Raises an ScenarioNotFoundException if the ID was not found
    # @param [String] value product ID
    def set_product_id(value)
      @product_id = value
      product = @yaml_configuration.find do |p|
        p.fetch('id', '') == @product_id
      end
      raise ProductNotFoundException, "Could not find product with ID '#{value}'" unless product
      @product = product.dup
      @product_name = @product['string_name']
    end

    # Scenario Name setter. Raises an ScenarioNotFoundException if the name was not found
    # @param [String] value scenario name
    def set_scenario_name(value)
      log.info "Selected scenario is '#{value}' for product '#{@product_name}'"
      raise ProductNotFoundException,
        "Setting scenario name before setting the Product ID" if @product.nil?
      @scenario_name = value
      @scenario = @product['scenarios'].find { |s| s['name'] == @scenario_name }
      if !@scenario
        log.error("Scenario name '#{@scenario_name}' not found in the scenario list")
        raise ScenarioNotFoundException
      end
      apply_scenario
    end

    def apply_scenario
      if @scenario['config_sequence']
        @config_sequence = @scenario['config_sequence'].map do |el|
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
            rpc_method:  "sapha.config_#{el}.apply"
          } 
        end
      else
        log.error "Scenario #{@scenario} does not set a configuration sequence."
        raise GUIFatal, "Scenario configuration is incorrect. Please check the logs."
      end
      @cluster.set_fixed_nodes(
        @scenario.fetch('fixed_number_of_nodes', false),
        @scenario.fetch('number_of_nodes', 2)
      )
    end

    def all_scenarios
      raise ProductNotFoundException,
        "Getting scenarios list before setting the Product ID" if @product.nil?
      @product['scenarios'].map { |s| s['name'] }
    end

    # Generate help string for all scenarios
    def scenarios_help
      raise ProductNotFoundException,
        "Getting scenarios help before setting the Product ID" if @product.nil?
      (@product['scenarios'].map { |s| s['description'] }).join('<br><br>')
    end

    # Can the cluster be set up?
    def can_install?
      return false if @config_sequence.empty?
      @config_sequence.map do |config|
        flag = config[:object].configured?
        log.warn "Component #{config[:screen_name]} is not configured" unless flag
        flag
      end.all?
    end

    def verbose_validate
      return ["Configuration sequence is empty"] if @config_sequence.empty?
      @config_sequence.map do |config|
        config[:object].validate
      end.flatten
    end

    # Dump this object to a YAML representation
    # @param [Boolean] slave
    def dump(slave = false)
      return unless can_install?
      # TODO: the proposals are also kept in this way of duplicating...
      old_role = @role
      @role = :slave if slave
      repr = YAML.dump self
      @role = old_role
      repr
    end

    # Below are the methods for logging the setup process
    def start_setup
      NodeLogger.info(
        "Starting setup process on node #{SapHA::NodeLogger.node_name}")
      true
    end

    def end_setup
      NodeLogger.info(
        "Finished setup process on node #{SapHA::NodeLogger.node_name}")
      true
    end

    def collect_log
      NodeLogger.text
    end

    private

    # Load scenarios from the YAML configuration file
    def load_scenarios
      YAML.load_file(SapHA::Helpers.data_file_path('scenarios.yaml'))
    end
  end # class ScenarioConfiguration
end # module Yast
