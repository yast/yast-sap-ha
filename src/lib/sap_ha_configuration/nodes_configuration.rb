# Class containing the configuration of nodes

module Yast
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
          ip_ring1: nil,
          ip_ring2: nil,
          node_id: i.to_s
        }
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  n = Yast::NodesConfiguration.new(2)
  puts n.inspect
  puts n.configured?
end