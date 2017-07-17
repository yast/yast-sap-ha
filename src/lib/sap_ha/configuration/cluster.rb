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
require_relative 'base_config'
require 'sap_ha/system/local'
require 'sap_ha/system/network'
require 'sap_ha/exceptions'

Yast.import 'UI'

module SapHA
  module Configuration
    # Cluster members configuration
    class Cluster < BaseConfig
      attr_reader :nodes, :rings, :number_of_rings, :transport_mode, :fixed_number_of_nodes, :keys
      attr_accessor :cluster_name, :expected_votes, :enable_secauth, :enable_csync2, :append_hosts,
                    :host_passwords

      include Yast::UIShortcuts
      include SapHA::Exceptions

      CSYNC2_INCLUDED_FILES = [
        '/etc/corosync/corosync.conf',
        '/etc/corosync/authkey',
        '/etc/sysconfig/pacemaker',
        '/etc/drbd.d',
        '/etc/drbd.conf',
        '/etc/lvm/lvm.conf',
        '/etc/multipath.conf',
        '/etc/ha.d/ldirectord.cf',
        '/etc/ctdb/nodes',
        '/etc/samba/smb.conf',
        '/etc/booth',
        '/etc/sysconfig/sbd',
        '/etc/csync2/csync2.cfg',
        '/etc/csync2/key_hagroup'
      ].freeze

      def initialize(global_config)
        super
        @screen_name = "Cluster Configuration"
        @fixed_number_of_nodes = false
        @number_of_nodes = 2
        @number_of_rings = 1
        @nodes = {}
        @rings = {}
        @transport_mode = :unicast
        @number_of_rings = 1
        @expected_votes = 2
        @exception_type = ClusterConfigurationException
        @cluster_name = 'hacluster'
        @enable_secauth = false
        @enable_csync2 = false
        @keys = {}
        @append_hosts = false
        # IP to root passwd mapping
        @host_passwords = {}
        init_rings
        init_nodes
        @yaml_exclude << :@host_passwords
      end

      def set_fixed_nodes(fixed, number)
        @fixed_number_of_nodes = fixed
        @number_of_nodes = number
        init_nodes
      end

      # return the table-like representation
      def nodes_table
        @nodes.map do |node_id, value|
          it = Item(Id(node_id), value[:node_id], value[:host_name], value[:ip_ring1])
          it << value[:ip_ring2] if @number_of_rings == 2
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

      def multicast?
        @transport_mode == :multicast
      end

      def rings_table
        if multicast?
          @rings.map { |k, v| Item(Id(k), k.to_s, v[:address], v[:port], v[:mcast]) }
        else
          @rings.map { |k, v| Item(Id(k), k.to_s, v[:address], v[:port]) }
        end
      end

      def update_ring(ring_id, values)
        @rings[ring_id][:port] = values[:port]
        if values[:address] != @rings[ring_id][:address]
          adr = IPAddr.new(values[:address]).succ
          @nodes.each { |_, n| n["ip_#{ring_id}".to_sym] = adr.to_s; adr = adr.succ }
          @rings[ring_id][:address] = values[:address]
          @rings[ring_id][:address_no_mask] = ip_split_mask(values[:address])
        end
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
        validate_comm_layer(:silent) && validate_nodes(:silent)
      end

      def comm_configured?
        validate_comm_layer(:silent)
      end

      def nodes_configured?
        validate_nodes(:silent)
      end

      def update_node(k, values)
        @nodes[k].update(values)
      end

      def render_csync2_config(group_name, includes, key_path, hosts)
        SapHA::Helpers.render_template('tmpl_csync2_config.erb', binding)
      end

      def description(component = :both)
        def comm_description(dsc)
          dsc.parameter('Transport mode', @transport_mode)
          dsc.parameter('Cluster name', @cluster_name)
          dsc.parameter('Expected votes', @expected_votes)
          dsc.parameter('Corosync secure authentication', @enable_secauth)
          dsc.parameter('Enable csync2', @enable_csync2)
          dsc.list_begin('Rings')
          @rings.each do |_, ring|
            str = "ring " << dsc.iparam(ring[:address]) << " : " << dsc.iparam(ring[:port])
            if multicast?
              str << ", mcast " << dsc.iparam(ring[:mcast])
            end
            dsc.list_item(str)
          end
          dsc.list_end
        end

        def nodes_description(dsc)
          dsc.list_begin('')
          @nodes.each do |_, node|
            str = "#{node[:host_name]}: " \
              << dsc.iparam([node[:ip_ring1], node[:ip_ring2]][0...@number_of_rings].join(", "))
            dsc.list_item(str)
          end
          dsc.list_end
          dsc.parameter('Append /etc/hosts', @append_hosts)
        end

        prepare_description do |dsc|
          case component
          when :nodes
            nodes_description(dsc)
          when :comm_layer
            comm_description(dsc)
          else
            nodes_description(dsc)
            comm_description(dsc)
          end
        end
      end

      def add_node(_values)
        if @fixed_number_of_nodes
          log.error "Scenario defined a fixed number of nodes #{@number_of_nodes},"\
            " but #{self.class}.#{__callee__} was called."
          return
        end
        # TODO: NW
      end

      def remove_node(_node_id)
        if @fixed_number_of_nodes
          log.error "Scenario defined a fixed number of nodes #{@number_of_nodes},"\
            " but #{self.class}.#{__callee__} was called."
          return
        end
        # TODO: NW
      end

      # return IPs of the first ring for nodes other than current node
      def other_nodes
        ips = @nodes.map { |_, n| n[:ip_ring1] } - SapHA::System::Network.ip_addresses
        return [] if ips.any?(&:empty?)
        ips
      end

      def set_host_password(ip, password)
        node = @nodes.values.find {|v| v[:ip_ring1] == ip }
        if node.nil?
          log.error "Trying to set password for node with IP #{ip}: No such node."
          return
        end
        @host_passwords[node[:host_name]] = password
      end

      def ring_addresses
        SapHA::System::Network.network_addresses_cidr
      end

      # TODO: rename and document
      def other_nodes_ext
        others_ip = other_nodes
        @nodes.map do |_, node|
          next unless others_ip.include? node[:ip_ring1]
          { hostname: node[:host_name], ip: node[:ip_ring1] }
        end.compact
      end

      def validate(verbosity = :verbose)
        validate_comm_layer(verbosity).concat(validate_nodes(verbosity))
      end

      def validate_comm_layer(verbosity = :verbose)
        SemanticChecks.instance.check(verbosity) do |check|
          check.equal(@rings.length, @number_of_rings,
            'Number of table entries is not equal to the number of allowed rings.')
          check.element_in_set(@transport_mode, [:unicast, :multicast],
            'The value should be either Unicast or Multicast', 'Transport Mode')
          check.element_in_set(@number_of_rings, [1, 2],
            'The value should be either 1 or 2', 'Number of Rings')
          check.identifier(@cluster_name, nil, 'Cluster Name')
          check.element_in_set(@enable_secauth, [true, false], nil,
            'Enable corosync secure authentication')
          check.element_in_set(@enable_csync2, [true, false], nil,
            'Enable csync2')
          @rings.each do |_, ring|
            ring_validator(check, ring)
          end
          check.unique(@rings.map { |_, r| r[:address] },
            'IP addresses of the rings are not unique')
        end
      end

      def validate_nodes(verbosity = :verbose)
        SemanticChecks.instance.check(verbosity) do |check|
          @nodes.map { |_, node| node_validator(check, node) }
          check.integer_in_range(@expected_votes, 1, @number_of_nodes, nil,
            'Expected votes')
          check.unique(@nodes.map { |_, v| v[:ip_ring1] },
            'IP addresses in ring #1 are not unique')
          check.ipsv4_in_network_cidr(@nodes.map { |_, v| v[:ip_ring1] },
            @rings[:ring1][:address], nil, 'IP addresses in ring #1')
          if @number_of_rings == 2
            check.unique(@nodes.map { |_, v| v[:ip_ring2] },
              'IP addresses in ring #2 are not unique')
            check.ipsv4_in_network_cidr(@nodes.map { |_, v| v[:ip_ring2] },
              @rings[:ring2][:address], nil, 'IP addresses in ring #2')
          end
          local_ips = SapHA::System::Network.ip_addresses
          # Local IPs can be empty if we're not running as root
          unless local_ips.empty?
            check.intersection_not_empty(@nodes.map { |_, v| v[:ip_ring1] }, local_ips,
              'Could not find local node\'s IP address among the configured nodes',
              'IP addresses for ring 1')
            check.intersection_not_empty(@nodes.map { |_, v| v[:ip_ring2] }, local_ips,
              'Could not find local node\'s IP address among the configured nodes',
              'IP addresses for ring 2') if @number_of_rings == 2
          end
        end
      end

      def node_validator(check, node)
        check.ipv4(node[:ip_ring1], 'IP Ring 1')
        check.ipv4_in_network_cidr(node[:ip_ring1], @rings[:ring1][:address], 'IP Ring 1')
        if @number_of_rings == 2
          check.ipv4(node[:ip_ring2], 'IP Ring 2')
          check.ipv4_in_network_cidr(node[:ip_ring2], @rings[:ring2][:address], 'IP Ring 2')
        end
        check.hostname(node[:host_name], 'Hostname')
        # check.nonneg_integer(node[:node_id], 'Node ID')
      end

      def ring_validator(check, ring)
        check.ipv4(ring[:address], 'Ring IP Address')
        check.port(ring[:port], 'Ring Port Number')
        check.ipv4_multicast(ring[:mcast], 'Multicast Address') if multicast?
      end

      def apply(role)
        @nlog.info('Applying Cluster Configuration')
        flag = true
        SapHA::System::Local.append_hosts_file(@nodes) if @append_hosts
        if role == :master
          @keys[:corosync] = generate_corosync_key if @enable_secauth
          @keys[:csync2] = generate_csync2_key if @enable_csync2
        else
          SapHA::System::Local.write_corosync_key(@keys[:corosync]) if @enable_secauth
          SapHA::System::Local.write_csync2_key(@keys[:csync2]) if @enable_csync2
        end
        status = cluster_apply
        @nlog.log_status(status, 'Exported configuration for yast2-cluster',
          'Could not export configuration for yast2-cluster')
        flag &= status
        flag &= SapHA::System::Local.start_cluster_services
        flag &= SapHA::System::Local.cluster_maintenance(:on) if role == :master
        flag &= SapHA::System::Local.add_stonith_resource if role == :master
        status = SapHA::System::Local.open_ports(role, @rings, @number_of_rings)
        flag &= status
        @nlog.log_status(status, 'Opened necessary communication ports',
          'Could not open necessary communication ports')
        flag
      end

      def html_errors(component = :both)
        case component
        when :comm_layer
          errors = validate_comm_layer(:verbose)
        when :nodes
          errors = validate_nodes(:verbose)
        else 
          errors = validate(:verbose)
        end
                  
        tmpl = "<ul>
        <% errors.each do |error| %>
          <li> <%= error %> </li>
        <% end %>
        </ul>
        "
        ERB.new(tmpl, nil, '-').result(binding)
      end

      private

      def init_nodes
        (1..@number_of_nodes).each do |i|
          @nodes["node#{i}".to_sym] = {
            host_name: "node#{i}",
            ip_ring1:  '',
            ip_ring2:  '',
            node_id:   i.to_s
          }
        end
      end

      def ip_split_mask(addr)
        addr.split('/').first
      end

      def init_rings
        (1..@number_of_rings).each do |ix|
          @rings["ring#{ix}".to_sym] = {
            address: '',
            port:    '5405',
            id:      ix,
            mcast:   ''
          }
        end
      end

      def generate_corosync_key
        return unless SapHA::System::Local.generate_corosync_key
        SapHA::System::Local.read_corosync_key
      end

      def generate_csync2_key
        return unless SapHA::System::Local.generate_csync2_key
        SapHA::System::Local.read_csync2_key
      end

      def cluster_apply
        cluster_export = generate_cluster_export
        SapHA::System::Local.yast_cluster_export(cluster_export)
        SapHA::System::Local.change_password('hacluster', 'linux')
      end

      def generate_cluster_export
        memberaddr = @nodes.map { |_, e| { addr1: e[:ip_ring1], addr2: e[:ip_ring2] } }
        memberaddr.each { |m| m.delete(:addr2) } unless @number_of_rings == 2
        host_names = @nodes.map { |_, e| e[:host_name] }
        cluster_configuration = {
          "secauth"        => @enable_secauth,
          "transport"      => (multicast? ? 'udp' : "udpu"),
          "bindnetaddr1"   => @rings[:ring1][:address_no_mask],
          "memberaddr"     => memberaddr,
          "mcastaddr1"     => @rings[:ring1][:mcast],
          "mcastport1"     => @rings[:ring1][:port],
          "cluster_name"   => @cluster_name,
          "expected_votes" => @expected_votes.to_s,
          "two_node"       => (@nodes.length == 2 ? '1' : '0'),
          "enable2"        => @number_of_rings == 2,
          "autoid"         => true,
          "rrpmode"        => "none",
          "csync2_host"    => host_names,
          "csync2_include" => CSYNC2_INCLUDED_FILES.dup
        }
        if cluster_configuration["enable2"]
          cluster_configuration["bindnetaddr2"] = @rings[:ring2][:address_no_mask]
          cluster_configuration["mcastaddr2"] = @rings[:ring2][:mcast]
          cluster_configuration["mcastport2"] = @rings[:ring2][:port]
        end
        cluster_configuration["csync2key"] = @keys[:csync2] if @keys[:csync2]
        cluster_configuration["corokey"] = @keys[:corosync] if @keys[:corosync]
        if @number_of_rings == 2
          # TODO: rrp mode
          cluster_configuration['rrpmode'] = 'passive'
        else
          cluster_configuration['rrpmode'] = 'none'
        end
        cluster_configuration
      end
    end # class Cluster
  end # module Configuration
end # module SapHA
