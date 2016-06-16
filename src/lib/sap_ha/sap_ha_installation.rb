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
require 'sap_ha_system/ssh'

module Yast
  class SAPHAInstallation
    include Yast::Logger

    def initialize(config, ui = nil)
      @config = config
      @yaml_config = config.dump(true)
      @ui = ui
      @logs = []
      prepare
    end

    def run
      local_configuration
      @ui.next_node if @ui
      log.error "--- #{self.class}.#{__callee__}: configuring remote nodes ---"
      for node in @other_nodes
        log.error "--- #{self.class}.#{__callee__}: configuring node #{node[:hostname]} ---"
        remote_configuration(node)
        @ui.next_node if @ui
        log.error "--- #{self.class}.#{__callee__}: finished configuring node #{node[:hostname]} ---"
      end
      if @ui
        @ui.unblock
      else
        log.error "--- #{self.class}.#{__callee__}: UI is screwed ---"
      end
      # make sure that the RPC servers are shut down
      for node in @other_nodes
        node[:rpc].call('sapha.shutdown') if node[:rpc]
      end
      @config.logs = @logs.join
      :next
    end

    private

    def remote_configuration(node)
      # Catch 'execution expired and start afresh'
      connect(node)
      @ui.next_task if @ui
      # Export config
      rpc = node[:rpc]
      rpc.call('sapha.import_config', @yaml_config)
      rpc.call('sapha.config.start_setup')
      @ui.next_task if @ui
      for component_id in @config.components
        log.error "--- #{self.class}.#{__callee__}: configuring component #{component_id} on node #{node[:hostname]} ---"
        func = "sapha.config_#{component_id.to_s[1..-1]}.apply"
        rpc.call(func, :slave)
        @ui.next_task
      end
      rpc.call('sapha.config.end_setup')
      @logs << rpc.call('sapha.config.collect_log')
    end


    def local_configuration
      log.error "--- #{self.class}.#{__callee__}: configuring current node ---"
      @ui.next_node if @ui
      @ui.next_task if @ui # we are not connecting to this node
      @config.start_setup
      for component_id in @config.components
        log.error "--- #{self.class}.#{__callee__}: configuring #{component_id} ---"
        @config.instance_variable_get(component_id).apply(:master)
        @ui.next_task if @ui
      end
      @config.end_setup
      @logs << @config.collect_log
      log.error "Log is #{@config.collect_log}"
      log.error "--- #{self.class}.#{__callee__}: finished ---"
    end

    def prepare
      # TODO: rename other_nodes_ext
      @other_nodes = @config.cluster.other_nodes_ext
      calculate_gui if @ui
    end

    def calculate_gui
      config_components = Hash[@config.components.map { |config_name|
        [config_name, @config.instance_variable_get(config_name).screen_name] }]
      tasks = ['Connecting']
      tasks.concat(config_components.map { |k, v| v })
      stages = ['Configure the local node']
      titles = ['Configuring the local node']
      @other_nodes.each do |n|
        stages << "Configure the remote node [#{n[:hostname]}]"
        titles << "Configuring the remote node [#{n[:hostname]}]"
      end
      @ui.set(stages, titles, tasks)
    end

    def connect(node)
      # TODO: catch all the SSH exceptions
      SSH.instance.run_rpc_server(node[:ip])
      sleep 5
      # TODO: catch 'Connection refused'
      node[:rpc] = XMLRPC::Client.new(node[:ip], "/RPC2", 8080)
    end
  end
end
