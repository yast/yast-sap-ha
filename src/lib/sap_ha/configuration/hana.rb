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
        :backup_user

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
      end

      def configured?
        # TODO: HANA validators
        !@virtual_ip.empty?
        SemanticChecks.instance.check(:silent) do |check|
          check.ipv4(@virtual_ip)
          check.integer_in_range(@instance, 0, 99)
          check.sap_sid(@system_id)
          # check.sap_site_name(@site_name_1)
          # check.sap_site_name(@site_name_2)
          # check.sap_backup_user(@backup_user)
          # check.sap_backup_file(@backup_file)
        end
      end

      def description
        "&nbsp; System ID: #{@system_id}, Instance: #{@instance}.<br>
        &nbsp; Virtual IP: #{@virtual_ip}.<br>
        &nbsp; Prefer takeover: #{@prefer_takeover}.<br>
        &nbsp; Automatic registration: #{@auto_register}.<br>
        &nbsp; Site 1: #{@site_name_1}, Site 2: #{@site_name_2}.<br>
        &nbsp; Backup user: #{@backup_user}, Backup file: #{@backup_file}.
        "
      end

      def apply(role)
        return false if !configured?
        @nlog.info('Appying HANA Configuration')
        if role == :master
          SapHA::System::Local.hana_make_backup(@backup_user, @backup_file, @instance)
          SapHA::System::Local.hana_enable_primary(@system_id, @site_name_1)
          # TODO
          # SapHA::System::Local.configure_crm
          configure_crm
        else
          # TODO: get the parameter from @CONFIG
          SapHA::System::Local.hana_enable_secondary(@system_id, @site_name_1, 'hana01', @instance)
        end
        true
      end

      def configure_crm
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
