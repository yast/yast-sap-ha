# -*- encoding: utf-8 -*-
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

require_relative '../../../../test_helper'
require 'sap_ha/exceptions'
require 'sap_ha/system/local'
require 'sap_ha/system/shell_commands'

describe SapHA::System::LocalClass do

  let(:bad_exit) {double('ExitStatus', exitstatus: 1)}
  let(:good_exit) {double('ExitStatus', exitstatus: 0)}

  describe '#block_devices' do
    it 'lists all block devices on this machine' do
      result = SapHA::System::Local.block_devices
      expect(result).not_to be_nil
    end
  end

  # # TODO: auto-generated
  # describe '#systemd_unit' do
  #   it 'works' do
  #     local_class = SapHA::System::LocalClass.new
  #     action = double('action')
  #     unit_type = double('unit_type')
  #     unit_name = double('unit_name')
  #     result = local_class.systemd_unit(action, unit_type, unit_name)
  #     expect(result).not_to be_nil
  #   end
  # end

  # # TODO: auto-generated
  # describe '#generate_csync_key' do
  #   it 'works' do
  #     local_class = SapHA::System::LocalClass.new
  #     result = local_class.generate_csync_key
  #     expect(result).not_to be_nil
  #   end
  # end

  # # TODO: auto-generated
  # describe '#generate_corosync_key' do
  #   it 'works' do
  #     local_class = SapHA::System::LocalClass.new
  #     result = local_class.generate_corosync_key
  #     expect(result).not_to be_nil
  #   end
  # end

  # # TODO: auto-generated
  # describe '#read_corosync_key' do
  #   it 'works' do
  #     local_class = SapHA::System::LocalClass.new
  #     result = local_class.read_corosync_key
  #     expect(result).not_to be_nil
  #   end
  # end

  # # TODO: auto-generated
  # describe '#join_cluster' do
  #   it 'works' do
  #     local_class = SapHA::System::LocalClass.new
  #     ip_address = double('ip_address')
  #     result = local_class.join_cluster(ip_address)
  #     expect(result).not_to be_nil
  #   end
  # end

  # # TODO: auto-generated
  # describe '#open_ports' do
  #   it 'works' do
  #     local_class = SapHA::System::LocalClass.new
  #     role = double('role')
  #     rings = double('rings')
  #     number_of_rings = double('number_of_rings')
  #     result = local_class.open_ports(role, rings, number_of_rings)
  #     expect(result).not_to be_nil
  #   end
  # end

  # # TODO: auto-generated
  # describe '#start_cluster_services' do
  #   it 'works' do
  #     local_class = SapHA::System::LocalClass.new
  #     result = local_class.start_cluster_services
  #     expect(result).not_to be_nil
  #   end
  # end

  # # TODO: auto-generated
  # describe '#yast_cluster_export' do
  #   it 'works' do
  #     local_class = SapHA::System::LocalClass.new
  #     settings = double('settings')
  #     result = local_class.yast_cluster_export(settings)
  #     expect(result).not_to be_nil
  #   end
  # end

  # # TODO: auto-generated
  # describe '#add_stonith_resource' do
  #   it 'works' do
  #     local_class = SapHA::System::LocalClass.new
  #     result = local_class.add_stonith_resource
  #     expect(result).not_to be_nil
  #   end
  # end

  # # TODO: auto-generated
  # describe '#initialize_sbd' do
  #   it 'works' do
  #     local_class = SapHA::System::LocalClass.new
  #     devices = double('devices')
  #     result = local_class.initialize_sbd(devices)
  #     expect(result).not_to be_nil
  #   end
  # end

  describe '#append_hosts_file' do
    let(:hosts) {
      {
        node1: {
          host_name: "hana01",
          ip_ring1:  "192.168.100.1",
          ip_ring2:  "",
          node_id:   1
        },
        node2: {
          host_name: "hana02",
          ip_ring1:  "192.168.100.2",
          ip_ring2:  "",
          node_id:   1
        }
      }
    }
    context 'when provided with a list of nodes in 1-ring configuration' do
      it 'writes the hosts file' do
        io = StringIO.new
        exp = "192.168.100.1\thana01 # added by yast2-sap-ha\n"\
          "192.168.100.2\thana02 # added by yast2-sap-ha\n"
        expect(File).to receive(:open).with('/etc/hosts', 'a').and_yield(io)
        SapHA::System::Local.append_hosts_file(hosts)
        expect(io.string).to eq exp
      end
    end

    context 'when provided with a list of nodes in 2-ring configuration' do
      it 'writes the hosts file' do
        io = StringIO.new
        exp = "192.168.100.1\thana01 # added by yast2-sap-ha\n"\
          "192.168.100.2\thana02 # added by yast2-sap-ha\n"
        hosts[:node1][:ip_ring2] = '192.168.101.1'
        hosts[:node2][:ip_ring2] = '192.168.101.2'
        expect(File).to receive(:open).with('/etc/hosts', 'a').and_yield(io)
        SapHA::System::Local.append_hosts_file(hosts)
        expect(io.string).to eq exp
      end
    end

  end

  # # TODO: auto-generated
  # describe '#generate_csync2_key' do
  #   it 'works' do
  #     local_class = SapHA::System::LocalClass.new
  #     result = local_class.generate_csync2_key
  #     expect(result).not_to be_nil
  #   end
  # end

  # # TODO: auto-generated
  # describe '#read_csync2_key' do
  #   it 'works' do
  #     local_class = SapHA::System::LocalClass.new
  #     result = local_class.read_csync2_key
  #     expect(result).not_to be_nil
  #   end
  # end

  # # TODO: auto-generated
  # describe '#write_csync2_key' do
  #   it 'works' do
  #     local_class = SapHA::System::LocalClass.new
  #     data = double('data')
  #     result = local_class.write_csync2_key(data)
  #     expect(result).not_to be_nil
  #   end
  # end

  # # TODO: auto-generated
  # describe '#write_corosync_key' do
  #   it 'works' do
  #     local_class = SapHA::System::LocalClass.new
  #     data = double('data')
  #     result = local_class.write_corosync_key(data)
  #     expect(result).not_to be_nil
  #   end
  # end

  describe '#cluster_maintenance' do
    it 'works' do
      expect(SapHA::System::Local).to receive(:exec_outerr_status)
        .with('crm', 'configure', 'property', 'maintenance-mode=true')
        .and_return(['', good_exit])
      result = SapHA::System::Local.cluster_maintenance(:on)
      expect(result).to eq true
      expect(SapHA::System::Local).to receive(:exec_outerr_status)
        .with('crm', 'configure', 'property', 'maintenance-mode=false')
        .and_return(['', good_exit])
      result = SapHA::System::Local.cluster_maintenance(:off)
      expect(result).to eq true
    end
  end
end
