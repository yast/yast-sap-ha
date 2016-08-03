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
# Summary: SUSE High Availability Setup for SAP Products: Node connectivity
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'socket'
require 'xmlrpc/client'
require 'sap_ha/exceptions'
require 'sap_ha/node_logger'
require_relative 'shell_commands'

module SapHA
  module System
    class Host < Hash
      include SapHA::Exceptions
      include Yast::Logger

      def initialize(host_name, ip_addresses)
        self[:host_name] = host_name
        self[:ip_addresses] = ip_addresses
        self[:rpc_client] = nil
      end

      def ip
        self[:ip_addresses].first
      end

      # Connect to the RPC server on the host
      def connect
        log.info "Creating a new RPC client for host #{self[:host_name]}" unless self[:rpc_client]
        self[:rpc_client] = XMLRPC::Client.new(ip, "/RPC2", 8080)
        begin
          call('sapha.ping')
        rescue StandardError => e
          log.error "Error connecting to the XML RPC server on node #{self[:host_name]}:"\
            "[#{e.class}] #{e.message}"
        end
      end

      # Connect to the host via SSH and run the server
      def run_rpc_server
        begin
          SapHA::System::SSH.instance.run_rpc_server(self[:host_name])
        rescue SSHException => e
          log.error e.message
          return false
        end
        true
      end

      def ping?
        call('sapha.ping')
      end

      # Perform a polling call: call the method that returns immediately,
      # then poll for status
      # This method blocks
      def polling_call(method_name, *args)
        raise RPCCallException, "Cannot call method #{method_name}: "\
          "client #{self[:host_name]} is not connected." unless self[:rpc_client]
        raise RPCCallException, "Node #{self[:host_name]} is busy configuring something!" if call('sapha.busy')

        retval = call(method_name, *args)
        return retval unless retval == "wait"
        # go into polling mode
        delay = 1
        while call("sapha.busy")
          log.info "--- #{self.class}.#{__callee__}: Remote node is busy. Retrying in #{delay} seconds. ---"
          sleep(delay)
          delay *= 2
          # one hour should be enough for an empty HANA to start, right?
          return false if delay >= 3_600
        end
        true
      end

      private

      # Wrap the .call method with exception handlers
      def call(method_name, *args)
        error_count = 0
        time_out = 1

        try_again = lambda do
          if error_count < 5
            error_count += 1
            time_out *= 2
            log.info "Retry \##{error_count} in #{time_out} seconds: "\
              "calling #{method_name}(#{args.join(', ')}) on node #{self[:host_name]}."
            sleep time_out
            return true
          else
            log.error "Tried #{error_count} times. Bailing out"
            return false
          end
        end

        begin
          self[:rpc_client].call(method_name, *args)
        rescue Errno::ECONNREFUSED => e
          log.error e.message
          retry if try_again.call
          raise RPCFatalException, "Could not connect to the RPC server on node #{self[:host_name]}: #{e.message}"
        rescue Net::HTTPBadResponse => e
          log.error "Got bad response from node #{self[:host_name]}: #{e.message}. Call #{method_name}(#{args.join(', ')})."
          retry if try_again.call
          raise RPCFatalException, "Got bad response from node #{self[:host_name]}: #{e.message}"
        rescue Net::ReadTimeout
          log.error "Call #{method_name}(#{args.join(', ')}) --- time out"
          retry if try_again.call
          raise RPCFatalException, "Call #{method_name}(#{args.join(', ')}) --- time out"
        rescue StandardError => e
          log.error "Call #{method_name}(#{args.join(', ')}): #{e.message}"
          retry if try_again.call
          raise RPCFatalException, "Call #{method_name}(#{args.join(', ')}): #{e.message}"
        end
      end
    end

    # Connectivity
    class ConnectivityClass
      include SapHA::Exceptions
      include Singleton
      include ShellCommands
      include Yast::Logger

      def initialize
        @nodes = {}
      end

      def add_node(host_name, ip_addresses)
        log.debug "--- #{self.class}.#{__callee__} added host #{host_name} with IP #{ip_addresses[0]} ---"
        @nodes[host_name] = Host.new(host_name, ip_addresses)
      end

      def list_nodes
        @nodes.keys
      end

      def init_from_config(cfg)
        cfg.other_nodes_ext.each do |node|
          @nodes[node[:hostname]] = Host.new(node[:hostname], [node[:ip]])
        end
      end

      # Start RPC servers on all nodes
      def run_rpc_servers
        # TODO: retry on failure or raise
        log.info "--- #{self.class}.#{__callee__} ---"
        @nodes.values.each do |host|
          host.run_rpc_server
        end
      end

      # Connect to all nodes
      def connect_to_all
        @nodes.values.each do |host|
          host.connect
        end
      end

      def check_connectivity
        @nodes.values.each do |host|
          host.ping?
        end.all?
      end

      def configure(host_name)
        raise RPCFatalException, "Could not find the host #{host_name}."\
          " Known hosts are: #{@nodes.keys}." unless @nodes[host_name]
        begin  
          yield @nodes[host_name]
        rescue
          
        end
      end


      def call(host_name, rpc_method, *args)
        raise RPCFatalException, "Could not find the host #{host_name}."\
          " Known hosts are: #{@nodes.keys}." unless @nodes[host_name]
        @nodes[host_name].polling_call(rpc_method, *args)
      end
    end

    Connectivity = ConnectivityClass.instance
  end
end
