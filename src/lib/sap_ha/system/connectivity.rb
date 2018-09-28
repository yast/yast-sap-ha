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
        self[:rpc_server_recovered] = false
      end

      def ip
        self[:ip_addresses].first
      end

      # Connect to the RPC server on the host
      def connect
        log.info "--- #{self.class}.#{__callee__} ---"
        log.info "Creating a new RPC client for host #{self[:host_name]}" unless self[:rpc_client]
        self[:rpc_client] = XMLRPC::Client.new(ip, "/RPC2", 8080)
        begin
          call('sapha.ping')
        rescue RPCRecoverableException => e
          log.debug "--- #{self.class}.#{__callee__}: Caught RPCRecoverableException ---"
          log.error "Error connecting to the XML RPC server on node #{self[:host_name]}: "\
            "[#{e.class}] #{e.message}"
          if self[:rpc_server_recovered]
            raise ConfigurationFatalException, e.message
          else
            log.error "Will try to recover"
            recover_rpc_server
          end
        rescue StandardError => e
          log.error "Error connecting to the XML RPC server on node #{self[:host_name]}: "\
            "[#{e.class}] #{e.message}"
          raise
        end
      end

      # Connect to the host via SSH and run the server
      def run_rpc_server
        log.info "--- #{self.class}.#{__callee__} ---"
        begin
          SapHA::System::SSH.instance.run_rpc_server(self[:host_name])
        rescue SSHException => e
          log.error e.message
          return false
        end
        true
      end

      def rpc_server_running?
        log.info "--- #{self.class}.#{__callee__} ---"
        SapHA::System::SSH.instance.rpc_server_running?(self[:host_name])
      end

      def stop_rpc_server
        log.info "--- #{self.class}.#{__callee__} ---"
        call('sapha.shutdown')
      end

      def kill_rpc_server
        log.info "--- #{self.class}.#{__callee__} ---"
        SapHA::System::SSH.instance.kill_rpc_server(self[:host_name])
      end

      # Try and recover RPC server on the remote node
      def recover_rpc_server
        log.info "--- #{self.class}.#{__callee__} ---"
        if rpc_server_running?
          log.info "RPC Server appears to be running on node #{self[:host_name]}"
          log.info "Will restart"
          stop_rpc_server
          self[:rpc_server_recovered] = true
          run_rpc_server
        else
          log.info "RPC Server appears to be not running on node #{self[:host_name]}"
          log.info "Will try to start it"
          self[:rpc_server_recovered] = true
          run_rpc_server
        end
      end

      def ping?
        log.info "--- #{self.class}.#{__callee__} ---"
        call('sapha.ping')
      end

      # Perform a polling call: call the method that returns immediately,
      # then poll for status
      # This method blocks
      def polling_call(method_name, *args)
        log.info "--- #{self.class}.#{__callee__}(#{method_name}, #{args}) ---"

        raise RPCCallException, "Cannot call method #{method_name}: "\
          "client #{self[:host_name]} is not connected." unless self[:rpc_client]
        raise RPCCallException, "Node #{self[:host_name]} is busy configuring something!" if call('sapha.busy')

        retval = call(method_name, *args)
        return retval unless retval == "wait"
        # go into polling mode
        slept = 0
        delay = 5
        while call("sapha.busy")
          log.info "--- #{self.class}.#{__callee__}: Remote node is busy. Retrying in #{delay} seconds. ---"
          sleep(delay)
          slept += delay
          # one hour should be enough for an empty HANA to start, right?
          return false if slept >= 3_600
        end
        true
      end

      private

      # Wrap the .call method with exception handlers
      def call(method_name, *args)
        log.info "--- #{self.class}.#{__callee__}(#{method_name}, #{args}) ---"
        error_count = 0
        time_out = 1

        try_again = lambda do
          if error_count < 5
            error_count += 1
            time_out *= 2
            log.info "Retry \##{error_count} in #{time_out} seconds: "\
              "calling #{method_name}(#{args.join(', ')}) on node #{self[:host_name]}."
            sleep(time_out)
            return true
          else
            log.error "Tried #{error_count} times. Bailing out"
            return false
          end
        end

        begin
          log.info "calling #{method_name}(#{args.join(', ')}) on node #{self[:host_name]}."
          self[:rpc_client].call(method_name, *args)
        rescue Errno::ECONNREFUSED => e
          log.debug "--- #{self.class}.#{__callee__} :: caught Errno::ECONNREFUSED --- "
          log.error e.message
          retry if try_again.call
          raise RPCRecoverableException, "Could not connect to the RPC server on node #{self[:host_name]}: #{e.message}"
        rescue Net::HTTPBadResponse => e
          log.debug "--- #{self.class}.#{__callee__} :: caught Net::HTTPBadResponse --- "
          log.error "Got bad response from node #{self[:host_name]}: #{e.message}. Call #{method_name}(#{args.join(', ')})."
          retry if try_again.call
          raise RPCFatalException, "Got bad response from node #{self[:host_name]}: #{e.message}"
        rescue Net::ReadTimeout
          log.debug "--- #{self.class}.#{__callee__} :: caught Net::ReadTimeout --- "
          log.error "Call #{method_name}(#{args.join(', ')}) --- time out"
          retry if try_again.call
          raise RPCFatalException, "Call #{method_name}(#{args.join(', ')}) --- time out"
        rescue StandardError => e
          log.debug "--- #{self.class}.#{__callee__} :: caught StandardError --- "
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
        log.debug "--- #{self.class}.#{__callee__} ---"
        @nodes.keys
      end

      def init_from_config(cfg)
        log.debug "--- #{self.class}.#{__callee__} ---"
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
        log.debug "--- #{self.class}.#{__callee__} ---"
        @nodes.values.each do |host|
          host.connect
        end
      end

      def check_connectivity
        log.debug "--- #{self.class}.#{__callee__} ---"
        @nodes.values.each do |host|
          host.ping?
        end.all?
      end

      def configure(host_name)
        log.debug "--- #{self.class}.#{__callee__}(#{host_name}) ---"
        raise RPCFatalException, "Could not find the host #{host_name}."\
          " Known hosts are: #{@nodes.keys}." unless @nodes[host_name]
        begin
          yield @nodes[host_name]
        rescue

        end
      end


      def call(host_name, rpc_method, *args)
        log.debug "--- #{self.class}.#{__callee__}(#{host_name}, #{rpc_method}, #{args}) ---"
        raise RPCFatalException, "Could not find the host #{host_name}."\
          " Known hosts are: #{@nodes.keys}." unless @nodes[host_name]
        @nodes[host_name].polling_call(rpc_method, *args)
      end
    end

    Connectivity = ConnectivityClass.instance
  end
end
