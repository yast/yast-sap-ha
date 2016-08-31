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
require 'sap_ha/helpers'
require 'sap_ha/node_logger'
require_relative 'shell_commands'

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
      
      # List all block devices on the system
      def block_devices
        devices = {}
        Dir.glob('/dev/disk/by-*').map do |p|
          dev_map = Dir.glob(File.join(p, '*')).map { |e| [File.basename(e), e] }.to_h
          devices[File.basename(p)] = dev_map
        end
        # if there are no udev-generated IDs, fall-back to /dev/*
        out, status = exec_outerr_status('lsblk', '-nlp', '-oName', '-e11')
        if status.exitstatus != 0
          log.error "Failed calling lsblk: #{out}"
        else
          dev_map = out.split("\n").map { |e| [File.basename(e), e] }.to_h
          devices['by-device'] = dev_map
        end
        devices
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

      # Append the information from the Cluster Nodes screen to the /etc/hosts
      # @param hosts [Hash] hosts definition
      def append_hosts_file(hosts)
        out = nil
        success = false
        str = hosts.map do |_, h|
          "#{h[:ip_ring1]} #{h[:ip_ring2]}\t#{h[:host_name]} \# added by yast2-sap-ha"
        end.join("\n")
        begin
          File.open('/etc/hosts', 'a') { |fh| fh.puts(str) }
          success = true
        rescue StandardError => e
          out = e.message
        end
        NodeLogger.log_status(
          success,
          "Wrote host information to the /etc/hosts file",
          "Could not write host information to the /etc/hosts/file",
          out
        )
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
            "but the key data is empty. Key is not written."
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
        written = Yast::SuSEFirewall.Write
        if role == :master
          Yast::SuSEFirewall.ActivateConfiguration
        else
          written
        end
      end

      def change_password(user_name, password)
        cmd_string = "#{user_name}:#{password}"
        out, status = exec_outerr_status_stdin('chpasswd', cmd_string)
        NodeLogger.log_status(status.exitstatus == 0,
          "Changed password for user #{user_name}",
          "Could not change password for user #{user_name}",
          out)
      end

      def start_cluster_services
        success = true
        success &= systemd_unit(:enable, :service, 'sbd')
        success &= systemd_unit(:enable, :socket, 'csync2')
        success &= systemd_unit(:enable, :service, 'pacemaker')
        success &= systemd_unit(:start, :service, 'pacemaker')
        success &= systemd_unit(:enable, :service, 'hawk')
        success &= systemd_unit(:start, :service, 'hawk')
        NodeLogger.log_status(
          success,
          'Enabled and started cluster-required systemd units',
          'Could not enable and start cluster-required systemd units'
        )
      end

      def cluster_maintenance(action = :on)
        mm = action == :on ? 'true' : 'false'
        cmd = ['crm', 'configure', 'property', "maintenance-mode=#{mm}"]
        out, status = exec_outerr_status(*cmd)
        NodeLogger.log_status(
          status.exitstatus == 0,
          "Cluster maintenance mode turned #{action}",
          "Could not turn the maintenance mode #{action} for the cluster",
          out
        )
      end

      # Export to the Yast-Cluster module
      def yast_cluster_export(settings)
        log.debug "--- called #{self.class}.#{__callee__} ---"
        Yast::Cluster.Read
        Yast::Cluster.Import(settings)
        stat = Yast::Cluster.Write
        NodeLogger.log_status(stat, 'Wrote cluster settings', 'Could not write cluster settings')
      end

      # Add the SBD stonith resource to the cluster
      def add_stonith_resource
        log.debug "--- called #{self.class}.#{__callee__} ---"
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
        log.debug "--- called #{self.class}.#{__callee__} ---"
        flag = true
        devices.each do |device|
          log.warn "Initializing the SBD device on #{device}"
          status = exec_status('sbd', '-d', device, 'create')
          log.warn "SBD initialization on #{device} returned #{status.exitstatus}"
          flag &= NodeLogger.log_status(status.exitstatus == 0,
            "Successfully initialized the SBD device #{device}",
            "Could not initialize the SBD device #{device}"
          )
        end
        flag
      end
    end
    Local = LocalClass.instance
  end
end
