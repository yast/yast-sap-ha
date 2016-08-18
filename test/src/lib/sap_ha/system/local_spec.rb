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

  let(:hdb_version_output) {
    "HDB version info:
version:             1.00.121.00.1466466057
branch:              fa/hana1sp12
git hash:            c2be2aaf4b39603589c0db86f2d769302d2b15de
git merge time:      2016-06-21 01:40:57
weekstone:           0000.00.0
compile date:        2016-06-21 01:54:21
compile host:        ld7272
compile type:        rel
"
  }

  describe '#block_devices' do
    it 'lists all block devices on this machine' do
      result = SapHA::System::Local.block_devices
      expect(result).not_to be_nil
      expect(result).not_to be_empty unless build_service?
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

  describe '#hana_make_backup' do
    context 'when the call to hdbsql succedes,' do
      it 'creates the backup' do
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbsql', '-U', 'hanabackup', '"BACKUP DATA USING FILE (\'backup\')"')
          .and_return(['', good_exit])
        result = SapHA::System::Local.hana_make_backup('XXX', 'hanabackup', 'backup', '10')
        expect(result).to eq true
      end
    end

    context 'when the call to hdbsql fails,' do
      it 'does not create the backup' do
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbsql', '-U', 'hanabackup', '"BACKUP DATA USING FILE (\'backup\')"')
          .and_return(['Some error', bad_exit])
        result = SapHA::System::Local.hana_make_backup('XXX', 'hanabackup', 'backup', '10')
        expect(result).to eq false
      end
    end
  end


  describe '#hana_enable_primary' do
    context 'when the call to hdbnsutil succedes,' do
      it 'enables the SR on the primary node' do
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbnsutil', '-sr_enable', "--name=PRIMARY")
          .and_return(['', good_exit])
        result = SapHA::System::Local.hana_enable_primary('XXX', 'PRIMARY')
        expect(result).to eq true
      end
    end

    context 'when the call to hdbnsutil fails,' do
      it 'does not enable the SR on the primary node' do
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbnsutil', '-sr_enable', "--name=PRIMARY")
          .and_return(['Some error', bad_exit])
        result = SapHA::System::Local.hana_enable_primary('XXX', 'PRIMARY')
        expect(result).to eq false
      end
    end
  end

  describe '#hana_version' do
    context 'when the call to HDB version succedes' do
      it 'returns the version string' do
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'version')
          .and_return([hdb_version_output, good_exit])
        result = SapHA::System::Local.hana_version('XXX')
        expect(result).to eq '1.00.121'
      end
    end

    context 'when the call to HDB version succedes, but the version string is garbled' do
      it 'returns nil' do
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'version')
          .and_return(['', good_exit])
        result = SapHA::System::Local.hana_version('XXX')
        expect(result).to eq nil
      end
    end

    context 'when the call to HDB version fails' do
      it 'returns nil' do
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'version')
          .and_return(['', bad_exit])
        result = SapHA::System::Local.hana_version('XXX')
        expect(result).to eq nil
      end
    end
  end

  describe '#hana_enable_secondary' do
    context 'when the call to hdbnsutil succedes,' do
      it 'enables the SR on the secondary node' do
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'version')
          .and_return(['1.00.100', good_exit])
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbnsutil', '-sr_register', '--remoteHost=hana01',
            '--remoteInstance=10', '--mode=sync', '--name=SECONDARY')
          .and_return(['', good_exit])
        result = SapHA::System::Local.hana_enable_secondary('XXX', 'SECONDARY', 'hana01', '10')
        expect(result).to eq true
      end
    end

    context 'when the call to hdbnsutil fails,' do
      it 'does not enable the SR on the secondary node' do
        # by default we assume SPS<12 and --mode parameter
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'version')
          .and_return(['', good_exit])
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbnsutil', '-sr_register', '--remoteHost=hana01',
            '--remoteInstance=10', '--mode=sync', '--name=SECONDARY')
          .and_return(['Some error', bad_exit])
        result = SapHA::System::Local.hana_enable_secondary('XXX', 'SECONDARY', 'hana01', '10')
        expect(result).to eq false
      end
    end

    context 'when the call to hdbnsutil succeeds for HANA SPS12' do
      it 'enables the SR on the secondary node' do
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'version')
          .and_return([hdb_version_output, good_exit])
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbnsutil', '-sr_register', '--remoteHost=hana01',
            '--remoteInstance=10', '--replicationMode=sync', '--name=SECONDARY')
          .and_return(['', good_exit])
        result = SapHA::System::Local.hana_enable_secondary('XXX', 'SECONDARY', 'hana01', '10')
        expect(result).to eq true
      end
    end
  end

  describe '#hana_check_secure_store' do
    context 'when the storage is empty' do
      it 'returns an empty array' do
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbuserstore', 'list')
          .and_return ["DATA FILE       : /usr/sap/XXX/home/.hdb/hana01/SSFS_HDB.DAT\n\n", good_exit]
        result = SapHA::System::Local.hana_check_secure_store('XXX')
        expect(result).to eq []
      end
    end

    context 'when the storage is not empty' do
      it 'returns the list of the keys' do
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbuserstore', 'list')
          .and_return ["DATA FILE       : /usr/sap/XXX/home/.hdb/hana01/SSFS_HDB.DAT\nKEY FILE        : /usr/sap/XXX/home/.hdb/hana01/SSFS_HDB.KEY\n\nKEY FILE\n  ENV : localhost:909023\n  USER: uname\nKEY KEY1\n  ENV : locahost:30150\n  USER: uname\nKEY KEY10\n  ENV : locahost:30150\n  USER: uname\nKEY KEY2\n  ENV : locahost:30150\n  USER: uname\n",
            good_exit]
        result = SapHA::System::Local.hana_check_secure_store('XXX')
        expect(result).to match_array ['KEY1', 'KEY2', 'KEY10', 'FILE']
      end
    end

    context 'when the call to hdbuserstore fails' do
      it 'returns an empty array' do
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbuserstore', 'list')
          .and_return ["An error occured", bad_exit]
        result = SapHA::System::Local.hana_check_secure_store('XXX')
        expect(result).to eq []
      end
    end
  end


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
        exp = "192.168.100.1 \thana01 # added by yast2-sap-ha\n"\
          "192.168.100.2 \thana02 # added by yast2-sap-ha\n"
        expect(File).to receive(:open).with('/etc/hosts', 'a').and_yield(io)
        SapHA::System::Local.append_hosts_file(hosts)
        expect(io.string).to eq exp
      end
    end

    context 'when provided with a list of nodes in 2-ring configuration' do
      it 'writes the hosts file' do
        io = StringIO.new
        exp = "192.168.100.1 192.168.101.1\thana01 # added by yast2-sap-ha\n"\
          "192.168.100.2 192.168.101.2\thana02 # added by yast2-sap-ha\n"
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

  describe '#hana_hdb_start' do
    context 'when the call to HDB start succeedes' do
      it 'returns true' do
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'start')
          .and_return(['', good_exit])
        result = SapHA::System::Local.hana_hdb_start('XXX')
        expect(result).to eq true
      end
    end

    context 'when the call to HDB start fails' do
      it 'returns false' do
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'start')
          .and_return(['', bad_exit])
          .twice # we retry HANA stops and starts
        result = SapHA::System::Local.hana_hdb_start('XXX')
        expect(result).to eq false
      end
    end
  end

  describe '#hana_hdb_stop' do
    context 'when the call to HDB stop succeedes' do
      it 'returns true' do
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'stop')
          .and_return(['', good_exit])
        result = SapHA::System::Local.hana_hdb_stop('XXX')
        expect(result).to eq true
      end
    end

    context 'when the call to HDB stop fails' do
      it 'returns false' do
        expect(SapHA::System::Local).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'stop')
          .and_return(['', bad_exit])
          .twice # we retry HANA stops and starts
        result = SapHA::System::Local.hana_hdb_stop('XXX')
        expect(result).to eq false
      end
    end
  end
end
