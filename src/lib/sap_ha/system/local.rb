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
require_relative 'shell_commands'

Yast.import 'NetworkInterfaces'
Yast.import 'SystemdService'
Yast.import 'SystemdSocket'
Yast.import 'SuSEFirewallServices'
Yast.import 'SuSEFirewall'

module SapHA
  module System
    # Local node configuration class
    class LocalClass
      include Singleton
      include ShellCommands
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

      def enable_service(service_name)
        service = Yast::SystemdService.find(service_name)
        return false if service.nil?
        service.enable unless service.enabled?
      end

      def disable_service(service_name)
        service = Yast::SystemdService.find(service_name)
        return false if service.nil?
        service.disable if service.enabled?
      end

      def start_service(service_name)
        service = Yast::SystemdService.find(service_name)
        return false if service.nil?
        service.start
      end

      def stop_service(service_name)
        service = Yast::SystemdService.find(service_name)
        return false if service.nil?
        service.stop
      end

      def enable_socket(socket_name)
        socket = Yast::SystemdSocket.find(socket_name)
        return false if socket.nil?
        socket.enable unless socket.enabled?
      end

      def disable_socket(socket_name)
        socket = Yast::SystemdSocket.find(socket_name)
        return false if socket.nil?
        socket.disable if socket.enabled?
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
        Yast::SuSEFirewall.Read
        Yast::SuSEFirewall.SetServicesForZones(["service:cluster", "service:sshd"], ["EXT"], true)
        Yast::SuSEFirewall.Write
        Yast::SuSEFirewall.ActivateConfiguration if role == :master
        # TODO: make sure the configuration is activated on the exit of the XML RPC server
        # TODO: log
      end

      def start_cluster_services
        success = true
        success &= NodeLogger.enable_unit(enable_service('sbd'), 'sbd', :service)
        success &= NodeLogger.enable_unit(enable_socket('csync2'), 'csync2', :socket)
        success &= NodeLogger.enable_unit(enable_service('pacemaker'), 'pacemaker', :service)
        success &= NodeLogger.start_unit(start_service('pacemaker'), 'pacemaker', :service)
        success &= NodeLogger.enable_unit(enable_service('hawk'), 'hawk', :service)
        success &= NodeLogger.start_unit(start_service('hawk'), 'hawk', :service)
        success
      end

      # Export to the Yast-Cluster module
      def cluster_export
        # TODO: move stuff from cluster.rb
      end
    end
    Local = LocalClass.instance
  end
end
