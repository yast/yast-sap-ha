require 'yast'
require 'erb'

require 'sap_ha_configuration/base_component_configuration.rb'
require 'sap_ha_configuration/nodes_configuration.rb'
require 'sap_ha_configuration/communication_configuration.rb'

module Yast
  # Exception
  class ProductNotFoundException < Exception
  end

  class ScenarioNotFoundException < Exception
  end

  # Scenario Configuration class
  class ScenarioConfiguration
    attr_accessor :product_id,
                  :product_name, :product,
                  :scenario_name, :scenario, :scenario_summary,
                  # nodes configuration
                  :conf_nodes,
                  # communication layer
                  :conf_communication

    include Yast::Logger
    include Yast::I18n

    def initialize
      @product_id = nil
      @product_name = nil
      @product = nil
      @scenario_name = nil
      @scenario = nil
      @scenario_summary = nil
      @conf_nodes = nil
      @conf_communication = nil
      @yaml_configuration = load_configuration
    end

    # Product ID setter. Raises an ScenarioNotFoundException if the ID was not found in the YAML file
    # @param [String] value product ID
    def product_id=(value)
      @product_id = value
      product = @yaml_configuration.find do |p|
        p['product'] && p['product'].fetch('id', '') == @product_id
      end
      raise ScenarioNotFoundException, "Could not find product1 with ID '#{value}'" unless product
      @product = product['product']
      @product_name = @product['string_name']
    end

    # Scenario Name setter. Raises an ScenarioNotFoundException if the name was not found in the YAML file
    # @param [String] value scenario name
    def scenario_name=(value)
      log.info "Selected scenario is '#{@value}'"
      @scenario_name = value
      @scenario = @product['scenarios'].find { |s| s['name'] == @scenario_name }
      if !@scenario
        log.error("Scenario name '#{@scenario_name}' not found in the scenario list")
        raise ScenarioNotFoundException
      end
      @conf_nodes = NodesConfiguration.new(@scenario['number_of_nodes'])
      @conf_communication = CommunicationConfiguration.new
    end

    def all_scenarios
      @product['scenarios'].map { |s| s['name'] }
    end

    def scenarios_help
      (@product['scenarios'].map { |s| s['description'] }).join('<br><br>')
    end

    private

    def load_configuration
      # TODO: check the file path
      YAML.load_file('data/scenarios.yaml')
    end
  end # class ScenarioConfiguration
end # module Yast
