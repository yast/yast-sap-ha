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
require 'sap_ha/node_logger'
require 'sap_ha/system/hana'
require 'sap_ha/system/local'
require 'sap_ha/system/shell_commands'

describe SapHA::System::HanaClass do

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

  let(:hdb_global_ini) {"/hana/shared/XXX/global/hdb/custom/config/global.ini"}

  describe '#make_backup' do
    context 'when the call to hdbsql succedes,' do
      it 'creates the backup' do
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbsql', '-U', 'hanabackup', '"BACKUP DATA USING FILE (\'backup\')"')
          .and_return(['', good_exit])
        result = SapHA::System::Hana.make_backup('XXX', 'hanabackup', 'backup', '10')
        expect(result).to eq true
      end
    end

    context 'when the call to hdbsql fails,' do
      it 'does not create the backup' do
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbsql', '-U', 'hanabackup', '"BACKUP DATA USING FILE (\'backup\')"')
          .and_return(['Some error', bad_exit])
        result = SapHA::System::Hana.make_backup('XXX', 'hanabackup', 'backup', '10')
        expect(result).to eq false
      end
    end
  end

  describe '#enable_primary' do
    context 'when the call to hdbnsutil succedes,' do
      it 'enables the SR on the primary node' do
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbnsutil', '-sr_enable', "--name=PRIMARY")
          .and_return(['', good_exit])
        result = SapHA::System::Hana.enable_primary('XXX', 'PRIMARY')
        expect(result).to eq true
      end
    end

    context 'when the call to hdbnsutil fails,' do
      it 'does not enable the SR on the primary node' do
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbnsutil', '-sr_enable', "--name=PRIMARY")
          .and_return(['Some error', bad_exit])
        result = SapHA::System::Hana.enable_primary('XXX', 'PRIMARY')
        expect(result).to eq false
      end
    end
  end

  describe '#version' do
    context 'when the call to HDB version succedes' do
      it 'returns the version string' do
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'version')
          .and_return([hdb_version_output, good_exit])
        result = SapHA::System::Hana.version('XXX')
        expect(result).to eq '1.00.121'
      end
    end

    context 'when the call to HDB version succedes, but the version string is garbled' do
      it 'returns nil' do
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'version')
          .and_return(['', good_exit])
        result = SapHA::System::Hana.version('XXX')
        expect(result).to eq nil
      end
    end

    context 'when the call to HDB version fails' do
      it 'returns nil' do
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'version')
          .and_return(['', bad_exit])
        result = SapHA::System::Hana.version('XXX')
        expect(result).to eq nil
      end
    end
  end

  describe '#enable_secondary' do
    context 'when the call to hdbnsutil succedes,' do
      it 'enables the SR on the secondary node' do
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'version')
          .and_return(['1.00.100', good_exit])
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbnsutil', '-sr_register', '--remoteHost=hana01',
            '--remoteInstance=10', '--mode=sync', '--name=SECONDARY')
          .and_return(['', good_exit])
        result = SapHA::System::Hana.enable_secondary('XXX', 'SECONDARY', 'hana01', '10', 'sync',
          'delta_datashipping')
        expect(result).to eq true
      end
    end

    context 'when the call to hdbnsutil fails,' do
      it 'does not enable the SR on the secondary node' do
        # by default we assume SPS<12 and --mode parameter
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'version')
          .and_return(['', good_exit])
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbnsutil', '-sr_register', '--remoteHost=hana01',
            '--remoteInstance=10', '--mode=sync', '--name=SECONDARY')
          .and_return(['Some error', bad_exit])
        result = SapHA::System::Hana.enable_secondary('XXX', 'SECONDARY', 'hana01', '10', 'sync',
          'delta_datashipping')
        expect(result).to eq false
      end
    end

    context 'when the call to hdbnsutil succeeds for HANA SPS12' do
      it 'enables the SR on the secondary node' do
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'version')
          .and_return([hdb_version_output, good_exit])
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbnsutil', '-sr_register', '--remoteHost=hana01',
            '--remoteInstance=10', '--replicationMode=sync', '--operationMode=delta_datashipping',
            '--name=SECONDARY')
          .and_return(['', good_exit])
        result = SapHA::System::Hana.enable_secondary('XXX', 'SECONDARY', 'hana01', '10','sync',
          'delta_datashipping')
        expect(result).to eq true
      end
    end
  end

  describe '#check_secure_store' do
    context 'when the storage is empty' do
      it 'returns an empty array' do
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbuserstore', 'list')
          .and_return ["DATA FILE       : /usr/sap/XXX/home/.hdb/hana01/SSFS_HDB.DAT\n\n", good_exit]
        result = SapHA::System::Hana.check_secure_store('XXX')
        expect(result).to eq []
      end
    end

    context 'when the storage is not empty' do
      it 'returns the list of the keys' do
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbuserstore', 'list')
          .and_return ["DATA FILE       : /usr/sap/XXX/home/.hdb/hana01/SSFS_HDB.DAT\nKEY FILE        : /usr/sap/XXX/home/.hdb/hana01/SSFS_HDB.KEY\n\nKEY FILE\n  ENV : localhost:909023\n  USER: uname\nKEY KEY1\n  ENV : locahost:30150\n  USER: uname\nKEY KEY10\n  ENV : locahost:30150\n  USER: uname\nKEY KEY2\n  ENV : locahost:30150\n  USER: uname\n",
            good_exit]
        result = SapHA::System::Hana.check_secure_store('XXX')
        expect(result).to match_array ['KEY1', 'KEY2', 'KEY10', 'FILE']
      end
    end

    context 'when the call to hdbuserstore fails' do
      it 'returns an empty array' do
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'hdbuserstore', 'list')
          .and_return ["An error occured", bad_exit]
        result = SapHA::System::Hana.check_secure_store('XXX')
        expect(result).to eq []
      end
    end
  end

  describe '#hdb_start' do
    context 'when the call to HDB start succeedes' do
      it 'returns true' do
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'start')
          .and_return(['', good_exit])
        result = SapHA::System::Hana.hdb_start('XXX')
        expect(result).to eq true
      end
    end

    context 'when the call to HDB start fails' do
      it 'returns false' do
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'start')
          .and_return(['', bad_exit])
          .twice # we retry HANA stops and starts
        result = SapHA::System::Hana.hdb_start('XXX')
        expect(result).to eq false
      end
    end
  end

  describe '#hdb_stop' do
    context 'when the call to HDB stop succeedes' do
      it 'returns true' do
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'stop')
          .and_return(['', good_exit])
        result = SapHA::System::Hana.hdb_stop('XXX')
        expect(result).to eq true
      end
    end

    context 'when the call to HDB stop fails' do
      it 'returns false' do
        expect(SapHA::System::Hana).to receive(:su_exec_outerr_status)
          .with('xxxadm', 'HDB', 'stop')
          .and_return(['', bad_exit])
          .twice # we retry HANA stops and starts
        result = SapHA::System::Hana.hdb_stop('XXX')
        expect(result).to eq false
      end
    end
  end

  describe '#write_sr_hook' do
    context 'given all prerequisites are satisfied' do
      it 'works' do
        io = StringIO.new
        expect(Dir).to receive(:mkdir).with('/hana/shared/XXX/srHook').and_return(0)
        expect(File).to receive(:open)
          .with('/hana/shared/XXX/srHook/srTakeover.py', 'wb')
          .and_yield(io)
        flag = SapHA::System::Hana.write_sr_hook('XXX', 'hook string')
        expect(flag).to eq(true), SapHA::NodeLogger.text
        expect(io.string).to eq 'hook string'
      end
    end

    context 'given the directory cannot be created' do
      it 'fails to write the hook file' do
        expect(Dir).to receive(:mkdir).with('/hana/shared/XXX/srHook').and_raise(Errno::ENOENT)
        flag = SapHA::System::Hana.write_sr_hook('XXX', 'hook string')
        expect(flag).to eq(false)
      end
    end

    context 'given that the file could not be opened' do
      it 'fails to write the hook file' do
        expect(Dir).to receive(:mkdir).with('/hana/shared/XXX/srHook').and_return(0)
        expect(File).to receive(:open).with('/hana/shared/XXX/srHook/srTakeover.py', 'wb')
          .and_raise(Errno::ENOENT)
        flag = SapHA::System::Hana.write_sr_hook('XXX', 'hook string')
        expect(flag).to eq(false)
      end
    end
  end

  # # TODO:
  # describe '#adjust_production_system' do
  #   context 'all is good' do
  #     it 'works' do
  #       io = StringIO.new
  #       expect(File).to receive(:exist?).with(any_args).and_call_original
  #       expect(File).to receive(:exist?).with(hdb_global_ini).and_return(true)
  #       expect(CFA::BaseModel).to receive(:initialize)
  #         .with(anything, hdb_global_ini)

  #       flag = SapHA::System::Hana.adjust_production_system('XXX', {})
  #       expect(flag).to eq(true), SapHA::NodeLogger.text
  #     end
  #   end
  # end

  # # TODO:
  # describe '#adjust_non_production_system' do
  #   it 'works' do
  #     hana_class = SapHA::System::HanaClass.new
  #     system_id = double('system_id')
  #     options = double('options')
  #     result = hana_class.adjust_non_production_system(system_id, options)
  #     expect(result).not_to be_nil
  #   end
  # end

  # # TODO:
  # describe '#create_monitoring_user' do
  #   it 'works' do
  #     hana_class = SapHA::System::HanaClass.new
  #     system_id = double('system_id')
  #     instance_number = double('instance_number')
  #     result = hana_class.create_monitoring_user(system_id, instance_number)
  #     expect(result).not_to be_nil
  #   end
  # end


end
