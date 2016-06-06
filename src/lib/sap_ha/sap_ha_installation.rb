require 'yast'
require 'xmlrpc/client'
require 'sap_ha_system/ssh'

module Yast
  class SAPHAInstallation
    include Yast::Logger

    def initialize(config, ui = nil)
      @config = config
      @ui = ui
      prepare
    end

    def prepare
      # other_nodes_ip = @config.cluster_members.other_nodes
      # number_of_nodes = @config.cluster_members.number_of_nodes
      @other_nodes = @config.cluster_members.other_nodes_ext
      calculate_gui if @ui
      connect
    end

    def calculate_gui
      config_components = Hash[@config.all_configs.map { |config_name|
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

    def connect
      @other_nodes.map do |node|
        SSH.instance.run_rpc_server(node[:ip])
        node[:rpc] = XMLRPC::Client.new(node[:ip], "/RPC2", 8080)
      end
    end

    def run
      (0...2).each do |i|
        @ui.next_node
        (0...7).each do |ix|
          sleep 1
          @ui.next_task
        end
      end
    end
  end
end