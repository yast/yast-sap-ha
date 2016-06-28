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
# Summary: SUSE High Availability Setup for SAP Products: Cluster setup class
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'xmlrpc/client'
require 'sap_ha/system/ssh'
require 'sap_ha/node_logger'

module SapHA
  # class that controls the cluster configuration
  class SAPHAInstallation
    include Yast::Logger

    def initialize(config, ui = nil)
      @config = config
      @ui = ui
      prepare
      @yaml_config = nil
    end

    def run
      # perform local configuration first,
      # since it can change the state of the config
      local_configuration
      @yaml_config = @config.dump(true)
      next_node
      @other_nodes.each do |node|
        log.info "--- #{self.class}.#{__callee__}: configuring node #{node[:hostname]} ---"
        break unless remote_configuration(node)
        next_node
        log.info "--- #{self.class}.#{__callee__}: finished configuring node #{node[:hostname]} ---"
      end
      @ui.unblock if @ui
      # make sure that the RPC servers are shut down
      @other_nodes.each do |node|
        node[:rpc].call('sapha.shutdown') if node[:rpc]
      end
      NodeLogger.summary
      :next
    end

    private

    def next_task
      @ui.next_task if @ui
    end

    def next_node
      @ui.next_node if @ui
    end

    def remote_configuration(node)
      # Catch 'execution expired and start afresh'
      connected = false
      attempt = 0
      while !connected && attempt < 5
        connected = connect(node)
        unless connected
          NodeLogger.error "Could not connect to node #{node} (attempt #{attempt})"
          sleep 3
        end
      end
      unless connected
        NodeLogger.fatal "Could not connect to node #{node}. Cluster setup is interrupted."
        return false
      end

      next_task
      # Export config
      rpc = node[:rpc]
      rpc.call('sapha.import_config', @yaml_config)
      rpc.call('sapha.config.start_setup')
      next_task
      @config.config_sequence.each do |component|
        log.info "--- #{self.class}.#{__callee__}: configuring component "\
          "#{component[:screen_name]} on node #{node[:hostname]} ---"
        rpc.call(component[:rpc_method], :slave)
        next_task
      end
      rpc.call('sapha.config.end_setup')
      NodeLogger.import rpc.call('sapha.config.collect_log')
      true
    end

    def local_configuration
      log.info "--- #{self.class}.#{__callee__}: configuring current node ---"
      next_node
      next_task # we are not connecting to the local node
      @config.start_setup
      @config.config_sequence.each do |component|
        log.info "--- #{self.class}.#{__callee__}: configuring #{component[:screen_name]} ---"
        component[:object].apply(:master)
        next_task
      end
      @config.end_setup
    end

    def prepare
      # TODO: rename other_nodes_ext
      @other_nodes = @config.cluster.other_nodes_ext
      calculate_gui if @ui
    end

    def calculate_gui
      tasks = ['Connecting']
      tasks.concat(@config.config_sequence.map { |e| e[:screen_name] })
      stages = ['Configure the local node']
      titles = ['Configuring the local node']
      @other_nodes.each do |n|
        stages << "Configure the remote node [#{n[:hostname]}]"
        titles << "Configuring the remote node [#{n[:hostname]}]"
      end
      @ui.set(stages, titles, tasks)
    end

    def connect(node)
      begin
        SapHA::System::SSH.instance.run_rpc_server(node[:ip])
      rescue SSHException => e
        log.error e.message
        return false
      end
      sleep 3
      # TODO: catch 'Connection refused'
      # TODO: catch 'execution expired'
      node[:rpc] = XMLRPC::Client.new(node[:ip], "/RPC2", 8080)
      begin
        node[:rpc].call('ping')
      rescue StandardError => e
        log.error "Error connecting to the XML RPC server on node #{node}:"\
          "[#{e.class}] #{e.message}"

      end
      true
    end
  end
end
