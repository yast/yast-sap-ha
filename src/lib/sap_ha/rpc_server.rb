#!/usr/bin/ruby
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
# Summary: SUSE High Availability Setup for SAP Products: XML RPC Server
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

ENV['Y2DIR'] = File.expand_path('../../../../src', __FILE__)

require 'yast'
require "xmlrpc/server"
require "sap_ha/configuration"
require "sap_ha/helpers"
require "sap_ha/system/shell_commands"
require 'yaml'

Yast.import 'SuSEFirewall'
Yast.import 'Service'

module SapHA
  # RPC Server for inter-node communication
  #
  # Exposes the following functions in the sapha.* namespace:
  #  - load_config(yaml_string) : recreates the marshalled config on the RPC Server's side
  #  - config : returns the @config object
  #  - config_{sub_config}.* : exposed methods of components' configurations
  class RPCServer
    include System::ShellCommands

    def initialize
      @fh = File.open('/tmp/rpc_serv', 'wb')
      @server = XMLRPC::Server.new(8080, '0.0.0.0', 3, @fh)
      # @config = Yast::Configuration.new :slave
      open_port
      install_handlers
    end

    def install_handlers
      @server.add_introspection

      @server.add_handler('sapha.import_config') do |yaml_string|
        @config = YAML.load(yaml_string)
        @server.add_handler('sapha.config', @config)
        for config_name in @config.components
          func = "sapha.config_#{config_name.to_s[1..-1]}"
          obj = @config.instance_variable_get(config_name)
          @server.add_handler(func, obj)
        end
        true
      end

      @server.add_handler('sapha.ping') do
        true
      end

      @server.add_handler('sapha.shutdown') do
        shutdown
      end
    end

    def start
      @server.serve
    end

    def shutdown
      Thread.new { sleep 3; @server.shutdown }
      true
    end

    def open_port
      rule_no = get_rule_number
      return if rule_no
      rc, out = exec_status_lo('/usr/sbin/iptables', '-I',
        'INPUT', '1', '-p', 'tcp', '--dport', '8080', '-j', 'ACCEPT')
      rc.exitstatus == 0
    end

    def close_port
      rule_no = get_rule_number
      puts "close_port: rule_no=#{rule_no} #{!!rule_no}"
      return unless rule_no
      rc, out = exec_status_lo('/usr/sbin/iptables', '-D', 'INPUT', rule_no.to_s)
      puts "close_port: rc=#{rc}, out=#{out}"
      rc.exitstatus == 0
    end

    def get_rule_number
      out = pipeline(['/usr/sbin/iptables', '-L', 'INPUT', '-n', '-v', '--line-number'],
        ['/usr/bin/awk', '$11 == "tcp" && $12 == "dpt:8080" && $4 == "ACCEPT" { print $1 }'])
      return nil if out.empty?
      Integer(out.strip)
    end

    def write_log(str)
      @fh.write(str)
      @fh.flush
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  server = SapHA::RPCServer.new
  at_exit { server.shutdown }
  server.start
  server.close_port
  Yast::SuSEFirewall.ActivateConfiguration
  # TODO: what if we demonize the process, by returning 0 at a successful server start?
end
