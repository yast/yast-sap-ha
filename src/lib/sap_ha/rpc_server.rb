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
require 'yaml'

module SAPHA
  # RPC Server for inter-node communication
  #
  # Exposes the following functions in the sapha.* namespace:
  #  - load_config(yaml_string) : recreates the marshalled config on the RPC Server's side
  #  - config : returns the @config object
  #  - 
  class RPCServer
    def initialize
      @server = XMLRPC::Server.new(8080, '0.0.0.0', maxConnections=3) #, stdlog=@fh)
      @config = Yast::ScenarioConfiguration.new :slave
      open_port
      install_handlers
    end

    def install_handlers
      @server.add_handler('sapha.load_config') do |yaml_string|
        @config = YAML::load(yaml_string)
        @server.add_handler('sapha.config', @config)
        set_subconf_handlers
        true
      end

      @server.add_handler('sapha.shutdown') do 
        shutdown
      end
    end

    def set_subconf_handlers
      for config_name in @config.all_configs
        func = "sapha.config_#{config_name.to_s[1..-1]}"
        obj = @config.instance_variable_get(config_name)
        @server.add_handler(func, obj)
      end
    end

    def start
      @server.serve
    end

    def shutdown
      close_port
      @server.shutdown
    end

    private

    def open_port
      rule_no = get_rule_number
      return if rule_no
      out = `/usr/sbin/iptables -I INPUT 1 -p tcp --dport 8080 -j ACCEPT`
      rc = $?.exitstatus
      puts "opening port:#{$?.exitstatus}: #{out}"
    end

    def close_port
      rule_no = get_rule_number
      out = `/usr/sbin/iptables -D INPUT #{rule_no}`
      rc = $?.exitstatus
      puts "closing port:#{$?.exitstatus}: #{out}"
    end

    def get_rule_number
      out = `/usr/sbin/iptables -L INPUT -n -v --line-number | /usr/bin/awk '$11 == "tcp" && $12 == "dpt:8080" && $4 == "ACCEPT" { print $1 }'`
      return nil if out.empty?
      Integer(out.strip)
    end
  end
end

if __FILE__ == $0
  server = SAPHA::RPCServer.new
  at_exit { server.shutdown }
  server.start
end