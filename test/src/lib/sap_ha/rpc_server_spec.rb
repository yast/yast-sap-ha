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
# Summary: SUSE High Availability Setup for SAP Products
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require_relative "../../../test_helper"
require "sap_ha/rpc_server"
require "xmlrpc/client"

describe SapHA::RPCServer do
  describe "RPC configuration" do
    before(:all) do
      @server = SapHA::RPCServer.new(local: true, test: true)
      @server_thread = Thread.new do
        @server.start
        @server = nil
      end
      @client = XMLRPC::Client.new("127.0.0.1", "/RPC2", 8080)
    end

    after(:all) do
      @server.immediate_shutdown
      sleep(3)
    end

    it "exposes required methods" do
      methods_list = @client.call("system.listMethods")
      expect(methods_list).to include("sapha.ping", "sapha.import_config", "sapha.shutdown")
    end

    it "pongs" do
      ret = @client.call("sapha.ping")
      expect(ret).to eq true
    end

    it "imports the config and exposes additional methods" do
      config = prepare_hana_config(nil, transport_mode: :unicast, number_of_rings: 1)
      yaml_config = config.dump(true)
      ret = @client.call("sapha.import_config", yaml_config)
      expect(ret).to eq true

      methods_list = @client.call("system.listMethods")

      # check the configuration sequence
      config_sequence = config.config_sequence
      config_sequence.each do |c|
        expect(methods_list).to include(c[:rpc_method]),
          "RPC method #{c[:rpc_method]} is not exposed"
        # sig = @client.call('system.methodSignature', c[:rpc_method])
        # expect(sig).to eq(['role']),
        #   "RPC method #{c[:rpc_method]} does not accept the parameter 'role': #{sig}"
      end
    end

    it "shuts down the server" do
      expect(@server).not_to be_nil
      @client.call("sapha.shutdown")
      sleep 3
      expect { @client.call("sapha.ping") }.to raise_error(Errno::ECONNREFUSED)
    end
  end
end
