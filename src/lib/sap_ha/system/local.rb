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
# Summary: SUSE High Availability Setup for SAP Products: Local system configuration
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'socket'
require 'sap_ha/exceptions'
require 'sap_ha/node_logger'
require_relative 'shell_commands'

Yast.import 'NetworkInterfaces'
Yast.import 'SystemdService'
Yast.import 'SystemdSocket'
Yast.import 'SuSEFirewallServices'
Yast.import 'SuSEFirewall'
Yast.import 'Cluster'

module SapHA
  module System
    # Local node configuration class
    class LocalClass
      include Singleton
      include ShellCommands
      include SapHA::Exceptions
      include Yast::Logger

      COROSYNC_KEY_PATH = '/etc/corosync/authkey'.freeze
      CSYNC2_KEY_PATH = '/etc/csync2/key_hagroup'.freeze

      def net_interfaces
        Yast::NetworkInterfaces.Read
        Yast::NetworkInterfaces.List("")
      end

      # Get local machine's IPv4 addresses excluding the loopback iface
      def ip_addresses
        interfaces = Socket.getifaddrs.select do |iface|
          iface.addr.ipv4? && !iface.addr.ipv4_loopback?
        end
        interfaces.map { |iface| iface.addr.ip_address }
      end

      # Get a list of network addresses on the local node's interface
      def network_addresses
        interfaces = Socket.getifaddrs.select do |iface|
          iface.addr.ipv4? && !iface.addr.ipv4_loopback?
        end
        interfaces.map do |iface|
          IPAddr.new(iface.addr.ip_address).mask(iface.netmask.ip_address).to_s
        end
      end

      def hostname
        Socket.gethostname
      end

      def block_devices
        out, status = exec_outerr_status('lsblk', '-pnio', 'KNAME,TYPE,LABEL,UUID')
        if status.exitstatus != 0
          log.error "Failed calling lsblk: #{out}"
          return []
        end
        devices = out.split("\n").map do |s|
          Hash[[:name, :type, :uuid].zip(s.split)]
        end
        devices.select { |d| d[:type] == "part" || d[:type] == "disk" || d[:type] == "lvm" }
      end

      # Change the systemd's unit state
      # @param action [Symbol] :enable, :disable, :start, :stop
      # @param unit_type [Symbol] :service or :socket
      # @param unit_name [String]
      def systemd_unit(action, unit_type, unit_name)
        verbs = { start: "Started", stop: "Stopped", enable: "Enabled", disable: "Disabled" }
        unless verbs.keys.include? action
          raise LocalSystemException, "Unknown action #{action} on systemd #{unit_type}"
        end
        unit = if unit_type == :service
                 Yast::SystemdService.find(unit_name)
               else
                 Yast::SystemdSocket.find(unit_name)
               end
        if unit.nil?
          NodeLogger.error "Could not #{action} #{unit_type} "\
          "#{unit_name}: #{unit_type} does not exist"
          return false
        end
        status = unit.send(action)
        if status
          verb = verbs[action]
          NodeLogger.info "#{verb} #{unit_type} #{unit_name}"
        else
          NodeLogger.error "Could not #{action} #{unit_type} #{unit_name}"
          NodeLogger.output unit.status unless unit.status.empty?
        end
        status
      end

      def generate_csync2_key
        out, status = exec_outerr_status('/usr/sbin/csync2', '-k', CSYNC2_KEY_PATH)
        NodeLogger.log_status(status.exitstatus == 0,
          "Generated the csync2 authentication key",
          "Could not generate the csync2 authentication key",
          out)
      end

      def read_csync2_key
        out, status = exec_outerr_status('uuencode', '-m', CSYNC2_KEY_PATH, '/dev/stdout')
        return out if status.exitstatus == 0
        NodeLogger.error "Could not read the csync2 authentication key"
        NodeLogger.output out
        nil
      end

      def write_csync2_key(data)
        if data.nil?
          NodeLogger.warn "Attempted to write the csync2 secure key, "\
            "but the key data is empty"
          return false
        end
        status = pipe(['echo', data], ['uudecode', '-o', CSYNC2_KEY_PATH])
        NodeLogger.log_status(status,
          "Wrote the shared csync2 authentication key",
          "Could not write the shared csync2 authentication key")
      end

      def generate_corosync_key
        out, status = exec_outerr_status('/usr/sbin/corosync-keygen', '-l')
        NodeLogger.log_status(status.exitstatus == 0,
          "Generated the corosync authentication key",
          "Could not generate the corosync authentication key",
          out)
      end

      def read_corosync_key
        out, status = exec_outerr_status('uuencode', '-m', COROSYNC_KEY_PATH, '/dev/stdout')
        return out if status.exitstatus == 0
        NodeLogger.error "Could not read the corosync authentication key"
        NodeLogger.output out
        nil
      end

      def write_corosync_key(data)
        if data.nil?
          NodeLogger.warn "Attempted to write the corosync secure authentication key, "\
            "but the key data is empty"
          return false
        end
        status = pipe(['echo', data], ['uudecode', '-o', COROSYNC_KEY_PATH])
        NodeLogger.log_status(status,
          "Wrote the shared corosync secure authentication key",
          "Could not write the shared corosync secure authentication key")
      end

      # join an existing cluster
      def join_cluster(_ip_address)
        raise 'Not implemented'
      end

      def open_ports(role, rings, number_of_rings)
        # 30865 for csync2
        # 5560 for mgmtd
        # 7630 for hawk2
        # 21064 for dlm
        tcp_ports = ["30865", "5560", "7630", "21064"]
        udp_ports = rings.map { |_, r| r[:port].to_s }[0...number_of_rings].uniq
        Yast::SuSEFirewallServices.SetNeededPortsAndProtocols(
          "service:cluster", "tcp_ports" => tcp_ports, "udp_ports" => udp_ports)
        Yast::SuSEFirewall.ResetReadFlag
        Yast::SuSEFirewall.Read
        Yast::SuSEFirewall.SetServicesForZones(["service:cluster", "service:sshd"], ["EXT"], true)
        Yast::SuSEFirewall.Write
        if role == :master
          Yast::SuSEFirewall.ActivateConfiguration
        else
          written
        end
      end

      def start_cluster_services
        success = true
        success &= systemd_unit(:enable, :service, 'sbd')
        success &= systemd_unit(:enable, :socket, 'csync2')
        success &= systemd_unit(:enable, :service, 'pacemaker')
        success &= systemd_unit(:start, :service, 'pacemaker')
        success &= systemd_unit(:enable, :service, 'hawk')
        success &= systemd_unit(:start, :service, 'hawk')
        success
      end

      # Export to the Yast-Cluster module
      def yast_cluster_export(settings)
        Yast::Cluster.Import(settings)
        stat = Yast::Cluster.Write
        NodeLogger.log_status(stat, 'Wrote cluster settings', 'Could not write cluster settings')
      end

      # Add the SBD stonith resource to the cluster
      def add_stonith_resource
        out, status = exec_outerr_status('crm', 'configure',
          'primitive', 'stonith-sbd', 'stonith:external/sbd')
        NodeLogger.log_status(status.exitstatus == 0,
          'Added a primitive to the cluster: stonith-sbd',
          'Could not add the stonith-sbd primitive to the cluster',
          out
        )
      end

      # Initialize the SBD devices
      # @param devices [Array[String]] devices paths
      def initialize_sbd(devices)
        flag = true
        devices.each do |device|
          log.warn "Initializing the SBD device on #{device[:name]}"
          status = exec_status_l('sbd', '-d', device[:name], 'create')
          log.warn "SBD initialization on #{device[:name]} returned #{status.exitstatus}"
          flag &= NodeLogger.log_status(status.exitstatus == 0,
            "Successfully initialized the SBD device #{device[:name]}",
            "Could not initialize the SBD device #{device[:name]}"
          )
        end
        flag
      end

      # Make initial HANA backup for the system replication
      # @param user_name [String] HANA username to perform the backup on behalf of
      # @param file_name [String] HANA backup file
      # @param instance_number [String] HANA instance number
      def hana_make_backup(user_name, file_name, instance_number)
        command = ['hdbsql']
        command << (user_name == 'system' ? '-u' : '-U')
        command << user_name
        command << '-i' << instance_number if user_name == 'system'
        command << "BACKUP DATA USING FILE ('#{file_name}')"
        out, status = exec_outerr_status(*command)
        NodeLogger.log_status(status.exitstatus == 0,
          "Created an initial HANA backup for user #{user_name} into file #{file_name}",
          "Could not perform an initial HANA backup for user #{user_name} into file #{file_name}",
          out
        )
      end

      # Enable System Replication on the primary HANA system
      # @param system_id [String] HANA System ID
      # @param site_name [String] HANA site name of the primary instance
      def hana_enable_primary(system_id, site_name)
        user_name = "#{system_id.downcase}adm"
        command = ['hdbnsutil', '-sr_enable', "--name=#{site_name}"]
        out, status = su_exec_outerr_status(user_name, *command)
        NodeLogger.log_status(status.exitstatus == 0,
          "Enabled HANA System Replication on the primary site #{site_name}",
          "Could not enable HANA System Replication on the primary site #{site_name}",
          out
        )
      end

      # Enable System Replication on the secondary HANA system
      # @param system_id [String] HANA System ID
      # @param site_name [String] HANA site name of the secondary instance
      # @param host_name_primary [String] host name of the primary node
      # @param instance [String] instance number of the primary
      # @param mode [String] replication mode
      def hana_enable_secondary(system_id, site_name, host_name_primary, instance, mode = 'sync')
        user_name = "#{system_id.downcase}adm"
        command = ['hdbnsutil', '-sr_register', "--remoteHost=#{host_name_primary}",
                   "--remoteInstance=#{instance}", "--mode=#{mode}", "--name=#{site_name}"]
        out, status = su_exec_outerr_status(user_name, *command)
        NodeLogger.log_status(status.exitstatus == 0,
          "Enabled HANA System Replication on the secondary host #{site_name}",
          "Could not enable HANA System Replication on the secondary host",
          out
        )
      end
    end

    Local = LocalClass.instance
  end
end
