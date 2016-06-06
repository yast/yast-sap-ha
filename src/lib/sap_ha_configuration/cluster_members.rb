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
# Summary: SUSE High Availability Setup for SAP Products: Cluster members configuration
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'erb'
require 'socket'
require_relative 'base_component_configuration.rb'

Yast.import 'UI'

module Yast
  class ClusterMembersConfigurationException < SAPHAException
  end

  # Cluster members configuration
  # TODO: think of merging this one and the CommLayer
  class ClusterMembersConfiguration < BaseComponentConfiguration
    attr_reader :nodes, :number_of_rings, :number_of_nodes

    include Yast::UIShortcuts
    include Yast::Logger # TODO: rm

    def initialize(number_of_nodes = 0)
      super()
      @screen_name = "Cluster Members Configuration"
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
      @nodes.all? { |_, v| !v[:ip_ring1].empty? }
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

    # return IPs of the first ring for nodes other than current node
    def other_nodes
      my_ips = Socket.getifaddrs.select do |iface| 
        iface.addr.ipv4? && !iface.addr.ip_address.start_with?("127.")
      end.map{|iface| iface.addr.ip_address}
      log.error "#{@nodes}"
      ips = @nodes.map { |_, n| n[:ip_ring1] } - my_ips
      raise ClusterMembersConfigurationException, "Empty IPs detected" if ips.any? { |e| e.empty? }
      ips
    end

    def other_nodes_ext
      others_ip = other_nodes
      @nodes.map do |k, node|
        next unless others_ip.include? node[:ip_ring1]
        {hostname: node[:host_name], ip: node[:ip_ring1]}
      end.compact
    end

    def number_of_rings=(value)
      @number_of_rings = value
      log.info "--- #{self.class}.#{__callee__}: number_of_rings <- #{value} ---"
    end

    def apply(role)
      return false if !configured?
    end

    private

    def init_nodes
      (1..@number_of_nodes).each do |i|
        @nodes["node#{i}".to_sym] = {
          host_name: "node#{i}",
          ip_ring1:  '',
          ip_ring2:  '',
          ip_ring3:  '',
          node_id:   i.to_s
        }
      end
    end
  end
end
