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
require 'sap_ha/system/network'
require_relative 'base_config'

module SapHA
  module Configuration
    # HANA configuration
    class HANA < BaseConfig
      attr_accessor :system_id,
        :instance,
        :np_system_id,
        :np_instance,
        :virtual_ip,
        :virtual_ip_mask,
        :prefer_takeover,
        :auto_register,
        :site_name_1,
        :site_name_2,
        :backup_file,
        :backup_user,
        :perform_backup,
        :replication_mode,
        :additional_instance,
        :hook_script,
        :hook_script_parameters,
        :production_constraints

      HANA_REPLICATION_MODES = ['sync', 'syncmem', 'async'].freeze

      include Yast::UIShortcuts
      include SapHA::System::ShellCommands

      def initialize(global_config)
        super
        @screen_name = "HANA Configuration"
        @system_id = 'NDB'
        @instance = '00'
        @virtual_ip = ''
        @virtual_ip_mask = '24'
        @replication_mode = HANA_REPLICATION_MODES.first
        @prefer_takeover = true
        @auto_register = false
        @site_name_1 = 'WALLDORF'
        @site_name_2 = 'ROT'
        @backup_user = 'system'
        @backup_file = 'backup'
        @perform_backup = true
        # Extended configuration for Cost-Optimized scenario
        @additional_instance = false
        @np_system_id = 'QAS'
        @np_instance = '10'
        @hook_script_parameters = {}
        @production_constraints = {}
        @hook_script = ""
      end

      def additional_instance=(value)
        @additional_instance = value
        return unless value
        @hook_script_parameters = {
          generated:            false,
          hook_execution_order: '1',
          hook_db_user_name:    'system',
          hook_db_password:     '',
          hook_port_number:     '3' + @instance + '15',
          hook_db_instance:     '10'
        }
        @production_constraints = {
          global_alloc_limit:    65_536.to_s,
          preload_column_tables: 'false'
        }
      end

      def configured?
        validate(:silent)
      end

      def validate(verbosity = :verbose)
        SemanticChecks.instance.check(verbosity) do |check|
          check.ipv4(@virtual_ip, 'Virtual IP')
          check.nonneg_integer(@virtual_ip_mask, 'Virtual IP mask')
          check.integer_in_range(@virtual_ip_mask, 1, 32, 'CIDR mask has to be between 1 and 32.',
            'Virtual IP mask')
          check.sap_instance_number(@instance, nil, 'Instance Number')
          check.sap_sid(@system_id, nil, 'System ID')
          check.element_in_set(@replication_mode, HANA_REPLICATION_MODES,
            "Value should be one of the following: #{HANA_REPLICATION_MODES.join(',')}.",
            'Replication mode'
          )
          check.identifier(@site_name_1, nil, 'Site name 1')
          check.identifier(@site_name_2, nil, 'Site name 2')
          check.element_in_set(@prefer_takeover, [true, false],
            nil, 'Prefer site takeover')
          check.element_in_set(@auto_register, [true, false],
            nil, 'Automatic registration')
          check.element_in_set(@perform_backup, [true, false],
            nil, 'Perform backup')
          # Backup settings should be only validated on the master node
          if @perform_backup && @global_config.role == :master
            check.identifier(@backup_file, nil, 'Backup settings/Backup file name')
            check.identifier(@backup_user, nil, 'Backup settings/Secure store key')
            keys = SapHA::System::Local.hana_check_secure_store(@system_id).map(&:downcase)
            check.element_in_set(@backup_user.downcase, keys,
              "There is no such HANA user store key detected.", 'Secure store key')
          end
          if @additional_instance
            check.sap_instance_number(@np_instance, nil, 'Non-Production Instance Number')
            check.sap_sid(@np_system_id, nil, 'Non-Production System ID')
            check.not_equal(@instance, @np_instance, 'SAP HANA instance numbers should not collide',
              'Instance number')
            check.not_equal(@system_id, @np_system_id, 'SAP HANA System IDs should not collide',
              'System ID')
            hook_script_validation(check, @hook_script_parameters)
            production_constraints_validation(check, @production_constraints)
            check.non_empty_string(@hook_script, "The failover hook script was not generated.",
              '', true)
          end
        end
      end

      def description
        prepare_description do |dsc|
          dsc.header('Production instance') if @additional_instance
          dsc.parameter('System ID', @system_id)
          dsc.parameter('Instance', @instance)
          dsc.parameter('Replication mode', @replication_mode)
          dsc.parameter('Virtual IP', @virtual_ip + '/' + @virtual_ip_mask)
          dsc.parameter('Prefer takeover', @prefer_takeover)
          dsc.parameter('Automatic registration', @auto_register)
          dsc.parameter('Site 1 name', @site_name_1)
          dsc.parameter('Site 2 name', @site_name_2)
          dsc.parameter('Perform backup', @perform_backup)
          if @perform_backup
            dsc.parameter('Secure store key', @backup_user)
            dsc.parameter('Backup file', @backup_file)
          end
          if @additional_instance
            dsc.header('Non-production instance')
            dsc.parameter('System ID', @np_system_id)
            dsc.parameter('Instance', @np_instance)
            dsc.header('Production system constraints')
            dsc.parameter('Global allocation limit (MB)', @production_constraints[:global_alloc_limit])
            dsc.parameter('Column tables preload', @production_constraints[:preload_column_tables])
          end
        end
      end

      def hook_generated?
        @hook_script_parameters[:generated]
      end

      def hook_script_parameters=(value)
        @hook_script_parameters = value
        @hook_script_parameters[:hook_port_number] = '3' + @instance + '15'
        @hook_script_parameters[:hook_db_instance] = @instance
        @hook_script = SapHA::Helpers.render_template('tmpl_srhook.py.erb', binding)
        @hook_script_parameters[:generated] = true
      end

      # Validator for the popup
      def hana_backup_validator(check, hash)
        check.identifier(hash[:backup_file], nil, 'Backup file name')
        check.identifier(hash[:backup_user], nil, 'Secure store key')
        keys = SapHA::System::Local.hana_check_secure_store(@system_id).map(&:downcase)
        check.element_in_set(hash[:backup_user].downcase, keys,
          "There is no such HANA user store key detected.", 'Secure store key')
      end

      def hook_script_validation(check, hash)
        check.nonneg_integer(hash[:hook_execution_order], 'Hook execution order')
        check.identifier(hash[:hook_db_user_name], nil, 'DB user name')
        check.port(hash[:hook_port_number], 'Port number')
      end

      def production_constraints_validation(check, hash)
        check.element_in_set(hash[:preload_column_tables], ['true', 'false'],
          'The field must contain a boolean value: "true" or "false"', 'Preload column tables')
        check.nonneg_integer(hash[:global_alloc_limit], 'Global allocation limit')
      end

      def apply(role)
        return false unless configured?
        @nlog.info('Appying HANA Configuration')
        if role == :master
          SapHA::System::Local.hana_hdb_start(@system_id)
          SapHA::System::Local.hana_make_backup(@system_id, @backup_user, @backup_file,
            @instance) if @perform_backup
          SapHA::System::Local.hana_enable_primary(@system_id, @site_name_1)
          configure_crm
        else
          SapHA::System::Local.hana_hdb_stop(@system_id)
          SapHA::System::Local.hana_write_sr_hook(@system_id, @hook_script)
          SapHA::System::Local.hana_adjust_production_system(@system_id,
            @hook_script_parameters.merge(@production_constraints))
          master_host = @global_config.cluster.other_nodes_ext.first[:hostname]
          SapHA::System::Local.hana_enable_secondary(@system_id, @site_name_2,
            master_host, @instance, @replication_mode)
        end
        true
      end

      def configure_crm
        # TODO: move this to SapHA::System::Local.configure_crm
        # TODO: generate a different config for cost_optimized scenario
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
