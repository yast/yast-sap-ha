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

module SAPHA
    class RPCServer
        def initialize
            log_file = Yast::SAPHAHelpers.instance.var_file_path('rpc_server.log')
            @fh = File.open(log_file, 'wb')
            @server = XMLRPC::Server.new(8080, '0.0.0.0', maxConnections=3, stdlog=@fh)
            install_handlers
            @server.serve
        end

        def install_handlers
            @server.add_handler('sapha.configure') do |config|
                "METHOD sapha.configure [#{config}]"
            end

            @server.add_handler('sapha.config_req') do |component, method, args|
                "METHOD sapha.config_req [#{component}, #{method}, #{args}]"
            end

            @server.add_handler('sapha.shutdown') do 
                shutdown
            end
        end

        def start
            @server.serve
        end

        def shutdown
            Process.kill("TERM", Process.pid)
        end
    end
end

if __FILE__ == $0
    server = SAPHA::RPCServer.new
    server.start
end