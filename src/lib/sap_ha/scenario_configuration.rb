require 'yast'
require 'erb'

module Yast
  # Exception
  class ProductNotFoundException < Exception
  end

  class ScenarioNotFoundException < Exception
  end

  # Scenario Configuration class
  class ScenarioConfiguration
    attr_accessor :product_id, :product_name, :product,
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

    def product_id=(value)
      @product_id = value
      product = @yaml_configuration.find do |p|
        p['product'] && p['product'].fetch('id', '') == @product_id
      end
      raise ScenarioNotFoundException, "Could not find product1 with ID '#{value}'" unless product
      @product = product['product']
      @product_name = @product['string_name']
    end

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

  # Base class for component configuration
  class BaseComponentConfiguration
    def initialize
      @storage = {}
    end

    def print
      inspect
    end

    def configured?
      false
    end

    def description
      ""
    end
  end # class BaseComponentConfiguration

  # Class containing the configuration of nodes
  class NodesConfiguration < BaseComponentConfiguration
    attr_reader :nodes

    def initialize(number_of_nodes)
      @number_of_nodes = number_of_nodes
      @nodes = {}
      init_nodes
    end

    def node_parameters(node_id)
      @nodes[node_id]
    end

    # return the table-like representation
    def table_items
      @nodes.map do |node_id, value|
        [node_id, value[:host_name], value[:ip_ring1], value[:ip_ring2], value[:node_id]]
      end
    end

    def configured?
      @nodes.all? { |_, v| v.all? { |__, vv| !vv.nil? } }
    end

    def update_values(k, values)
      @nodes[k] = values
    end

    def description
      nodes = []
      @nodes.each do |_, node|
        nodes << "&nbsp; Node #{node[:node_id]}:
          #{node[:host_name]} (#{node[:ip_ring1]}/#{node[:ip_ring2]})"
      end
      nodes.join "<br>"
    end

    private

    def init_nodes
      (1..@number_of_nodes).each do |i|
        @nodes["node#{i}".to_sym] = {
          host_name: "node#{i}",
          ip_ring1:  nil,
          ip_ring2:  nil,
          node_id:   i.to_s
        }
      end
    end
  end # class NodesConfiguration

  # Communication Layer Configuration
  class CommunicationConfiguration < BaseComponentConfiguration
    def initialize
      @number_of_rings = 2
      @rings = {}
      init_rings
    end

    def init_rings
      (1..@number_of_rings).each do |i|
        @rings["ring#{i}".to_sym] = {
          address: nil,
          port:    nil
        }
      end
    end

    def table_items
    end
  end # class CommunicationConfiguration
end # module Yast

if __FILE__ == $PROGRAM_NAME
  n = Yast::NodesConfiguration.new(2)
  puts n.inspect
  puts n.configured?
end
