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
require 'sap_ha_system/shell_commands'
require_relative 'base_component_configuration.rb'

module Yast
  # HANA configuration
  class HANAConfiguration < BaseComponentConfiguration
    
    attr_accessor :system_id,
      :instance,
      :virtual_ip,
      :prefer_takeover,
      :auto_register

    include Yast::UIShortcuts
    include ShellCommands

    def initialize
      super
      @screen_name = "HANA Configuration"
      @system_id = 'NDB' # TODO
      @instance = '00'
      @virtual_ip = ''
      @prefer_takeover = true
      @auto_register = false
    end

    def configured?
      # TODO: HANA validators
      !@virtual_ip.empty?
      flag = true
      flag &= SemanticChecks.instance.check(:silent) do |check|
        check.ipv4(@virtual_ip)
        check.integer_in_range(@instance, 0, 99)
        check.sap_sid(@system_id)
      end
    end

    def description
      "&nbsp; System ID: #{@system_id}, Instance: #{@instance}.<br>
      &nbsp; Virtual IP: #{@virtual_ip}.<br>
      &nbsp; Prefer takeover: #{@prefer_takeover}.<br>
      &nbsp; Automatic Registration: #{@auto_register}.
      "
    end

    def apply(role)
      return false if !configured?
      # TODO: implement
      return true

      if role == :master
        hana_make_backup
        hana_enable_primary
        configure_crm
      elsif role == :slave
        hana_enable_secondary
      end
      true
    end

    def hana_make_backup
      # TODO: the user name has to come from the user
      cmd = 'hdbsql -u system -i 00 "BACKUP DATA USING FILE (\'backup\')"'
    end

    def hana_enable_primary
      # issue as the SIDadm user
      # TODO: site name has to come from the user
      # cmd = "hdbnsutil -sr_enable --name=WALLDORF"
      # exec_status_l('su', get_adm_user, 'hdbnsutil', '-sr_enable', '--name=WALLDORF')
      true
    end

    def hana_enable_secondary
      # issued on the secondary node from SIDadm
      # TODO: here we need to obtain a hostname of the remote host
      # TODO: site name has to come from the user
      # TODO: mode can come from the user
      # cmd = 'hdbnsutil -sr_register --remoteHost=suse01 --remoteInstance=00 --mode=sync --name=ROT'
      # exec_status_l('su', get_adm_user, 'hdbnsutil', '-sr_register', "--remoteHost=#{primary_host}",
      # "--remoteInstance=#{@instance}", '--mode=sync', '--name=ROT')
      true
    end

    def configure_crm
      crm_conf = SAPHAHelpers.instance.render_template('tmpl_cluster_config.erb', binding)
      file_path = SAPHAHelpers.instance.write_var_file('cluster.config', crm_conf)
      status = exec_status_l('crm', 'configure', '--file', file_path)
      status.exitstatus == 0
    end

    def get_adm_user
      @system_id.downcase + 'adm'
    end
  end
end
