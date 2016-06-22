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
      
      def net_interfaces
        NetworkInterfaces.Read
        NetworkInterfaces.List("")
      end

      def ip_addresses
        Socket.getifaddrs.select do |iface|
          iface.addr.ipv4? && !iface.addr.ip_address.start_with?("127.")
        end.map{|iface| iface.addr.ip_address}
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
        out.split("\n").map do |s|
          Hash[[:name, :type, :uuid].zip(s.split)]
        end.select { |d| d[:type] == "part" || d[:type] == "disk" }
      end

      # Change the systemd's unit state
      # @param action [Symbol] :enable, :disable, :start, :stop
      # @param unit_type [Symbol] :service or :socket
      # @param unit_name [String]
      def systemd_unit(action, unit_type, unit_name)
        verbs = {start: "Started", stop: "Stopped", enable: "Enabled", disable: "Disabled"}
        unless verbs.keys.include? action
          raise LocalSystemException, "Unknown action #{action} on systemd #{unit_type}"
        end
        unit = if unit_type == :service
                 Yast::SystemdService.find(unit_name)
               else
                 Yast::SystemdSocket.find(unit_name)
               end
        if unit.nil?
          NodeLogger.error "Could not #{action} #{unit_type} #{unit_name}: #{unit_type} does not exist"
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

      def generate_csync_key

      end

      def generate_corosync_key
        ret = exec_status_l('/usr/sbin/corosync-keygen', '-l')
        ret.exitstatus
      end

      def read_corosync_key
        exec_status_l()
      end

      # join an existing cluster
      def join_cluster(ip_address)
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
          "service:cluster", { "tcp_ports" => tcp_ports, "udp_ports" => udp_ports})
        Yast::SuSEFirewall.ResetReadFlag
        Yast::SuSEFirewall.Read
        Yast::SuSEFirewall.SetServicesForZones(["service:cluster", "service:sshd"], ["EXT"], true)
        written = Yast::SuSEFirewall.Write
        # TODO: remove debug
        # if role == :master
        Yast::SuSEFirewall.ActivateConfiguration
        # else
        #   written
        # end
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

      def add_stonith_resource
        out, status = exec_outerr_status('crm', 'configure', 'primitive', 'stonith-sbd', 'stonith:external/sbd')
        success = status.exitstatus == 0
        if success
          NodeLogger.info('Added a primitive to the cluster: stonith-sbd')
        else
          NodeLogger.error('Could not add the stonith-sbd primitive to the cluster')
          NodeLogger.output(out)
        end
        success
      end

      def initialize_sbd(devices)
        flag = true
        for device in devices
          log.warn "Initializing the SBD device on #{device[:name]}"
          status = exec_status_l('sbd', '-d', device[:name], 'create')
          log.warn "SBD initialization on #{device[:name]} returned #{status.exitstatus}"
          if status.exitstatus == 0
            NodeLogger.info "Successfully initialized the SBD device #{device[:name]}"
          else
            NodeLogger.error "Could not initialize the SBD device #{device[:name]}"
          end
          flag &= status.exitstatus == 0
        end
        flag
      end

    end
    Local = LocalClass.instance
  end
end
