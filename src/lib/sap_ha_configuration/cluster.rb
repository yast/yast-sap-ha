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
  class ClusterConfigurationException < ModelValidationException
  end

  # Cluster members configuration
  # TODO: think of merging this one and the CommLayer
  class ClusterConfiguration < BaseComponentConfiguration
    attr_reader :nodes, :number_of_rings, :transport_mode
    attr_accessor :cluster_name, :expected_votes

    include Yast::UIShortcuts

    def initialize(fixed_number_of_nodes = nil)
      super()
      @screen_name = "Cluster Configuration"
      @fixed_number_of_nodes = fixed_number_of_nodes
      number_of_nodes = if fixed_number_of_nodes
                          fixed_number_of_nodes
                        else
                          2
                        end
      @number_of_rings = 1
      @nodes = {}
      @rings = {}
      @transport_mode = :unicast
      @number_of_rings = 1
      @expected_votes = 2
      @exception_type = ClusterConfigurationException
      @cluster_name = 'hacluster'
      init_rings
      init_nodes(number_of_nodes)
    end

    def node_parameters(node_id)
      @nodes[node_id]
    end

    # return the table-like representation
    def nodes_table_cont
      @nodes.map do |node_id, value|
        it = Item(Id(node_id), value[:node_id], value[:host_name], value[:ip_ring1])
        it << value[:ip_ring2] if @number_of_rings >= 2
        it << value[:ip_ring3] if @number_of_rings == 3
        it
      end
    end

    def number_of_rings=(value)
      @number_of_rings = value
      # reinit the items
      rings_old = @rings.dup
      @rings = {}
      (1..@number_of_rings).each do |ix|
        key = "ring#{ix}".to_sym
        if rings_old.key?(key)
          @rings[key] = rings_old[key]
        else
          @rings[key] = {
            address: '',
            port:    '',
            id:      ix,
            mcast:   ''
          }
        end
      end
    end

    def ring_info(ring_id)
      @rings[ring_id]
    end

    def multicast?
      @transport_mode == :multicast
    end

    def all_rings
      @rings.dup
    end

    def rings_table_cont
      if multicast?
        @rings.map { |k, v| Item(Id(k), k.to_s, v[:address], v[:port], v[:mcast]) }
      else
        @rings.map { |k, v| Item(Id(k), k.to_s, v[:address], v[:port]) }
      end
    end

    def update_ring(ring_id, values)
      [:address, :port].each { |e| @rings[ring_id][e] = values[e] }
      @rings[ring_id][:mcast] = values[:mcast] if multicast?
    end

    def transport_mode=(value)
      unless [:multicast, :unicast].include? value
        raise ModelValidationException,
          "Error setting transport mode to #{value}"
      end
      @transport_mode = value
    end

    def configured?
      flag = @rings.all? { |_, v| validate_ring(v, :silent) }
      flag &= SemanticChecks.instance.check(:silent) do |check|
        check.equal(@rings.length, @number_of_rings, 'Number of table entries is not 
          equal to the number of allowed rings.')
        check.identifier(@cluster_name, 'Cluster name is incorrect')
        check.integer_in_range(@expected_votes, 1, @nodes.length)
      end
      return flag unless flag
      flag &= @nodes.all? { |_, v| validate_node(v, :silent) }
      return flag unless flag
      flag &= SemanticChecks.instance.check(:silent) do |check|
        check.unique(@nodes.map { |_, v| v[:ip_ring1] })
        check.unique(@nodes.map { |_, v| v[:ip_ring2] }) if @number_of_rings >= 2
        check.unique(@nodes.map { |_, v| v[:ip_ring3] }) if @number_of_rings == 3
      end
      flag
    end

    def update_values(k, values)
      @nodes[k] = values
    end

    def validate_ring(ring, verbosity)
      SemanticChecks.instance.check(verbosity) do |check|
        check.ipv4(ring[:address], 'IP Address')
        check.port(ring[:port], 'Port Number')
        check.ipv4_multicast(ring[:mcast], 'Multicast Address') if multicast?
      end
    end

    def render_csync2_config(group_name, includes, key_path, hosts)
      return SAPHAHelpers.instance.render_template('tmpl_csync2_config.erb', binding)
    end

    def description
      tmp = ERB.new(
        '
          <% @nodes.each_with_index do |(k, nd), ix| %>
            <% ips = [nd[:ip_ring1], nd[:ip_ring2], nd[:ip_ring3]][0...@number_of_rings].join(", ") %>
            <%= "&nbsp; #{nd[:node_id]}. #{nd[:host_name]} (#{ips})." %>
            <% if ix != (@nodes.length-1) %>
              <%= "<br>" %>
            <% end %>
          <% end %>
        '
      )
      tmp.result(binding)
    end

    # def description
    #   a = []
    #   a << "&nbsp; Transport mode: #{@transport_mode}."
    #   a << "&nbsp; Cluster name: #{@cluster_name}."
    #   a << "&nbsp; Expected votes: #{@expected_votes}."
    #   @rings.each do |_, r|
    #     add = (@transport_mode == :multicast) ? ", mcast #{r[:mcast]}." : "."
    #     a << "&nbsp; #{r[:id]}. #{r[:address]}, port #{r[:port]}#{add}"
    #   end
    #   a.join('<br>')
    # end

    def fixed_number_of_nodes?
      !@fixed_number_of_nodes.nil?
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
      raise ClusterMembersConfException, "Empty IPs detected" if ips.any? { |e| e.empty? }
      ips
    end

    # TODO: rename and document
    def other_nodes_ext
      others_ip = other_nodes
      @nodes.map do |k, node|
        next unless others_ip.include? node[:ip_ring1]
        {hostname: node[:host_name], ip: node[:ip_ring1]}
      end.compact
    end

    # def number_of_rings=(value)
    #   @number_of_rings = value
    #   log.info "--- #{self.class}.#{__callee__}: number_of_rings <- #{value} ---"
    # end

    def apply(role)
      return false if !configured?
    end

    def validate
      # TODO
      super
    end

    def validate_node(node, verbosity)
      SemanticChecks.instance.check(verbosity) do |check|
        check.ipv4(node[:ip_ring1], 'IP Ring 1')
        check.ipv4(node[:ip_ring2], 'IP Ring 2') if @number_of_rings > 1
        check.ipv4(node[:ip_ring3], 'IP Ring 3') if @number_of_rings > 2
        check.hostname(node[:host_name], 'Hostname')
        check.nonneg_integer(node[:node_id], 'Node ID')
      end
    end

    def check_ssh_connectivity

    end

    private

    def init_nodes(number_of_nodes)
      (1..number_of_nodes).each do |i|
        @nodes["node#{i}".to_sym] = {
          host_name: "node#{i}",
          ip_ring1:  '',
          ip_ring2:  '',
          ip_ring3:  '',
          node_id:   i.to_s
        }
      end
    end

    def init_rings
      (1..@number_of_rings).each do |ix|
        @rings["ring#{ix}".to_sym] = {
          address: '',
          port:    '',
          id:      ix,
          mcast:   ''
        }
      end
    end
  end
end
