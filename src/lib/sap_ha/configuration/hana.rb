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
# Summary: SUSE High Availability Setup for SAP Products: HANA configuration
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'sap_ha/system/shell_commands'
require 'sap_ha/system/local'
require_relative 'base_config'

module SapHA
  module Configuration
    # HANA configuration
    class HANA < BaseConfig
      attr_accessor :system_id,
        :instance,
        :virtual_ip,
        :prefer_takeover,
        :auto_register,
        :site_name_1,
        :site_name_2,
        :backup_file,
        :backup_user,
        :perform_backup

      include Yast::UIShortcuts
      include SapHA::System::ShellCommands

      def initialize
        super
        @screen_name = "HANA Configuration"
        @system_id = 'HA1' # TODO
        @instance = '10'
        @virtual_ip = ''
        @prefer_takeover = true
        @auto_register = false
        @site_name_1 = 'WALLDORF'
        @site_name_2 = 'ROT'
        @backup_user = 'system'
        @backup_file = 'backup'
        @perform_backup = true
      end

      def configured?
        validate(:silent)
      end

      def validate(verbosity = :verbose)
        SemanticChecks.instance.check(verbosity) do |check|
          check.ipv4(@virtual_ip, 'Virtual IP')
          check.sap_instance_number(@instance, nil, 'Instance Number')
          check.sap_sid(@system_id, nil, 'System ID')
          check.identifier(@site_name_1, nil, 'Site name 1')
          check.identifier(@site_name_2, nil, 'Site name 2')
          check.identifier(@backup_user, nil, 'Backup user')
          check.identifier(@backup_file, nil, 'Backup file name')
          check.element_in_set(@perform_backup, [true, false],
            nil, 'Perform backup')
          if @perform_backup
            check.element_in_set(@prefer_takeover, [true, false],
              nil, 'Prefer site takeover')
            check.element_in_set(@auto_register, [true, false],
              nil, 'Automatic registration')
          end
        end
      end

      def description
        prepare_description do |dsc|
          dsc.parameter('System ID', @system_id)
          dsc.parameter('Instance', @instance)
          dsc.parameter('Virtual IP', @virtual_ip)
          dsc.parameter('Prefer takeover', @prefer_takeover)
          dsc.parameter('Automatic registration', @auto_register)
          dsc.parameter('Site 1 name', @site_name_1)
          dsc.parameter('Site 2 name', @site_name_2)
          dsc.parameter('Perform backup', @perform_backup)
          if @perform_backup
            dsc.parameter('Backup user', @backup_user)
            dsc.parameter('Backup file', @backup_file)
          end
        end
      end

      # Validator for the popup
      def hana_backup_validator(check, hash)
        check.element_in_set(hash[:perform_backup], [true, false],
          nil, 'Perform backup')
        return if hash[:perform_backup] == false
        check.identifier(hash[:backup_user], nil, 'Backup user')
        check.identifier(hash[:backup_file], nil, 'Backup file name')
      end

      def apply(role)
        return false if !configured?
        @nlog.info('Appying HANA Configuration')
        if role == :master
          SapHA::System::Local.hana_hdb_start(@system_id)
          SapHA::System::Local.hana_make_backup(@backup_user,
            @backup_file, @instance) if @perform_backup
          SapHA::System::Local.hana_enable_primary(@system_id, @site_name_1)
          configure_crm
        else
          SapHA::System::Local.hana_hdb_stop(@system_id)
          # TODO: the host name should be obtained from @config.cluster
          SapHA::System::Local.hana_enable_secondary(@system_id, @site_name_1, 'hana01', @instance)
        end
        true
      end

      def configure_crm
        # TODO: move this to SapHA::System::Local.configure_crm
        crm_conf = Helpers.render_template('tmpl_cluster_config.erb', binding)
        file_path = Helpers.write_var_file('cluster.config', crm_conf)
        out, status = exec_outerr_status('crm', '--file', file_path)
        @nlog.log_status(status.exitstatus == 0,
          'Configured necessary cluster resources for HANA',
          'Could not configure HANA cluster resources', out)
      end
    end
  end
end
