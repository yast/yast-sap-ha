require 'yast'
require 'erb'
require_relative 'base_component_configuration.rb'
Yast.import 'UI'

module Yast
  class ClusterMembersConfiguration < BaseComponentConfiguration
    attr_reader :nodes, :number_of_rings

    include Yast::UIShortcuts
    include Yast::Logger # TODO: rm

    def initialize(number_of_nodes=0)
      log.info "--- #{self.class}.#{__callee__} ---"
      @number_of_nodes = number_of_nodes
      @number_of_rings = 1
      @nodes = {}
      init_nodes
    end

    def node_parameters(node_id)
      @nodes[node_id]
    end

    # return the table-like representation
    def table_items
      @nodes.map do |node_id, value|
        it = Item(Id(node_id), value[:host_name], value[:ip_ring1])
        it << value[:ip_ring2] if @number_of_rings >= 2
        it << value[:ip_ring3] if @number_of_rings == 3
        it << value[:node_id]
        it
      end
    end

    def configured?
      @nodes.all? { |_, v| !v[:ip_ring1].empty?}
    end

    def update_values(k, values)
      @nodes[k] = values
    end

    def description
      tmp = ERB.new(
        '
          <% @nodes.each_with_index do |(k, nd), ix| %>
            <%= "&nbsp; <i>Node #{nd[:node_id]}:</i> #{nd[:host_name]} [#{nd[:ip_ring1]}" %>
            <% if @number_of_rings > 1 && !nd[:ip_ring2].empty? %>
              <%= " / #{nd[:ip_ring2]}" %>
            <% end %>
            <% if @number_of_rings > 2 && !nd[:ip_ring3].empty? %>
              <%= " / #{nd[:ip_ring3]}" %>
            <% end %>
            <%= "]" %>
            <% if ix != (@nodes.length-1) %>
              <%= "<br>" %>
            <% end %>
          <% end %>
        '
      )
      tmp.result(binding)
    end

    def fixed_number_of_nodes?
      @number_of_nodes != 0
    end

    def add_node(values)
      # TODO
    end

    def remove_node(node_id)
      # TODO
    end

    def number_of_rings=(value)
      @number_of_rings=value
      log.info "--- #{self.class}.#{__callee__}: number_of_rings <- #{value} ---"
    end

    private

    def init_nodes
      (1..@number_of_nodes).each do |i|
        @nodes["node#{i}".to_sym] = {
          host_name: "node#{i}",
          ip_ring1: '',
          ip_ring2: '',
          ip_ring3: '',
          node_id: i.to_s
        }
      end
    end
  end
end
