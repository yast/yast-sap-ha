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
# Summary: SUSE High Availability Setup for SAP Products: Module's configuration
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'erb'
require 'yaml'

require 'sap_ha_configuration/cluster_members.rb'
require 'sap_ha_configuration/communication_layer.rb'
require 'sap_ha_configuration/stonith.rb'
require 'sap_ha_configuration/watchdog.rb'
require 'sap_ha_configuration/hana.rb'
require 'sap_ha_configuration/ntp.rb'

module Yast
  # Exceptions
  class ProductNotFoundException < Exception
  end

  class ScenarioNotFoundException < Exception
  end

  # Module's configuration
  class ScenarioConfiguration
    # TODO: rename the class
    attr_reader :product_id,
      :scenario_name,
      :all_configs
    attr_accessor :role,
      :debug,
      :no_validators,
      :product_name,
      :product,
      :scenario,
      :scenario_summary,
      :cluster_members,
      :communication_layer,
      :stonith,
      :watchdog,
      :hana,
      :ntp

    include Yast::Logger
    include Yast::I18n

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
      @cluster_members = nil # This depends on the scenario configuration
      @communication_layer = CommunicationLayerConfiguration.new
      @yaml_configuration = load_scenarios
      @stonith = StonithConfiguration.new
      @watchdog = WatchdogConfiguration.new
      @hana = HANAConfiguration.new
      @ntp = NTPConfiguration.new
      @all_configs = [:@cluster_members, :@communication_layer, :@stonith, :@watchdog, :@ntp]
    end

    # Product ID setter. Raises an ScenarioNotFoundException if the ID was not found
    # @param [String] value product ID
    def set_product_id(value)
      @product_id = value
      product = @yaml_configuration.find do |p|
        p['product'] && p['product'].fetch('id', '') == @product_id
      end
      raise ProductNotFoundException, "Could not find product1 with ID '#{value}'" unless product
      @product = product['product']
      @product_name = @product['string_name']
      case @product_id
      when "HANA"
        @all_configs << :@hana
      when "NW"
        @all_configs << :@nw
      end
    end

    # Scenario Name setter. Raises an ScenarioNotFoundException if the name was not found
    # @param [String] value scenario name
    def set_scenario_name(value)
      log.info "Selected scenario is '#{value}' for product '#{@product_name}'"
      @scenario_name = value
      @scenario = @product['scenarios'].find { |s| s['name'] == @scenario_name }
      if !@scenario
        log.error("Scenario name '#{@scenario_name}' not found in the scenario list")
        raise ScenarioNotFoundException
      end
      @cluster_members = ClusterMembersConfiguration.new(@scenario['number_of_nodes'])
    end

    def all_scenarios
      @product['scenarios'].map { |s| s['name'] }
    end

    # Generate help string for all scenarios
    def scenarios_help
      (@product['scenarios'].map { |s| s['description'] }).join('<br><br>')
    end

    # Can the cluster be set up?
    def can_install?
      @all_configs.map do |config|
        next unless instance_variable_defined?(config)
        conf = instance_variable_get(config)
        next if conf.nil?
        conf.configured?
      end.all?
    end

    # Dump this object to a YAML representation
    # @param [Boolean] slave change the 
    def dump(slave = false)
      # TODO: the proposals are also kept in this way of duplicating...
      old_role = @role
      @role = :slave if slave
      repr = YAML.dump self
      @role = old_role
      repr
    end

    def apply_configs
      s_config = dump(true)

    end

    private

    # Load scenarios from the YAML configuration file
    def load_scenarios
      YAML.load_file(SAPHAHelpers.instance.data_file_path('scenarios.yaml'))
    end
  end # class ScenarioConfiguration
end # module Yast
