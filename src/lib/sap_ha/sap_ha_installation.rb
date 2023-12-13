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

require "yast"
require "xmlrpc/client"
require "sap_ha/system/ssh"
require "sap_ha/exceptions"
require "sap_ha/system/connectivity"
require "sap_ha/node_logger"

module SapHA
  # class that controls the cluster configuration
  class SAPHAInstallation
    include Yast::Logger
    include SapHA::Exceptions

    def initialize(config, ui = nil)
      @config = config
      @ui = ui
      @yaml_config = nil
      prepare
    end

    def run
      # perform local configuration first, since it can change the state of the config
      log.debug "--- #{self.class}.#{__callee__} ---"
      local_configuration
      @yaml_config = @config.dump(true)
      next_node
      @other_nodes.each do |node|
        log.info "--- #{self.class}.#{__callee__}: configuring node #{node[:hostname]} ---"
        begin
          remote_configuration(node)
        rescue SapHA::Exceptions::ConfigurationFatalException => e
          log.error "SAP HA Configuration was interrupted due to a fatal error: #{e.message}"
          NodeLogger.fatal "SAP HA Configuration was interrupted due to a fatal error: #{e.message}"
          @ui.unblock if @ui
          return :next
        end
        next_node
        log.info "--- #{self.class}.#{__callee__}: finished configuring node #{node[:hostname]} ---"
      end
      @config.hana.finalize
      @ui.unblock if @ui
      NodeLogger.summary
      :next
    end

  private

    def next_task
      log.debug "--- #{self.class}.#{__callee__} ---"
      @ui.next_task if @ui
    end

    def next_node
      log.debug "--- #{self.class}.#{__callee__} ---"
      @ui.next_node if @ui
    end

    def remote_configuration(node)
      log.debug "--- #{self.class}.#{__callee__}(#{node}) ---"
      next_task
      # Export config
      SapHA::System::Connectivity.configure(node[:hostname]) do |rpc|
        begin
          rpc.connect
          rpc.polling_call("sapha.import_config", @yaml_config)
          rpc.polling_call("sapha.config.start_setup")
        rescue SapHA::Exceptions::RPCRecoverableException => e
          log.debug "--- #{self.class}.#{__callee__}(#{node}) :: caught RPCRecoverableException ---"
          NodeLogger.fatal "Could not connect to node #{node[:hostname]}. Cluster setup is interrupted."
          raise SapHA::Exceptions::ConfigurationFatalException, e.message
        end
        next_task
        @config.config_sequence.each do |component|
          log.info "--- #{self.class}.#{__callee__}: configuring component "\
            "#{component[:screen_name]} on node #{node[:hostname]} ---"
          rpc.polling_call(component[:rpc_method], :slave)
          next_task
        end
        rpc.polling_call("sapha.config.end_setup")
        NodeLogger.import rpc.polling_call("sapha.config.collect_log")
        rpc.polling_call("sapha.shutdown")
      end
      true
    end

    def local_configuration
      log.debug "--- #{self.class}.#{__callee__} ---"
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
      log.debug "--- #{self.class}.#{__callee__} ---"
      # TODO: rename other_nodes_ext
      @other_nodes = @config.cluster.other_nodes_ext
      SapHA::System::Connectivity.init_from_config(@config.cluster)
      SapHA::System::Connectivity.run_rpc_servers
      calculate_gui if @ui
    end

    def calculate_gui
      log.debug "--- #{self.class}.#{__callee__} ---"
      tasks = ["Connecting"]
      tasks.concat(@config.config_sequence.map { |e| e[:screen_name] })
      stages = ["Configure local node"]
      titles = ["Configuring local node"]
      @other_nodes.each do |n|
        stages << "Configure remote node [#{n[:hostname]}]"
        titles << "Configuring remote node [#{n[:hostname]}]"
      end
      @ui.set(stages, titles, tasks)
    end
  end
end
