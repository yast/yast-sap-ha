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
# Authors: Peter Varkoly <varkoly@suse.com>
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require "yast"
require "sap_ha/system/shell_commands"
require "sap_ha/system/local"
require "sap_ha/system/hana"
require "sap_ha/system/network"
require_relative "base_config"

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
        :operation_mode,
        :additional_instance,
        :hook_script,
        :hook_script_parameters,
        :production_constraints

      HANA_REPLICATION_MODES = ["sync", "syncmem", "async"].freeze
      HANA_OPERATION_MODES = ["delta_datashipping", "logreplay"].freeze
      HANA_FW_SERVICES = [
        "hana-cockpit",
        "hana-database-client",
        "hana-data-provisioning",
        "hana-http-web-access",
        "hana-internal-distributed-communication",
        "hana-internal-system-replication",
        "hana-lifecycle-manager",
        "sap-software-provisioning-manager",
        "sap-special-support"
      ].freeze

      include Yast::UIShortcuts
      include SapHA::System::ShellCommands
      include Yast::Logger

      def initialize(global_config)
        super
        log.debug "--- #{self.class}.#{__callee__} ---"
        @screen_name = "HANA Configuration"
        @system_id = ""
        @instance = ""
        @virtual_ip = ""
        @virtual_ip_mask = "24"
        @replication_mode = HANA_REPLICATION_MODES.first
        @operation_mode = HANA_OPERATION_MODES.first
        @prefer_takeover = true
        @auto_register = false
        @site_name_1 = ""
        @site_name_2 = ""
        @backup_user = "system"
        @backup_file = "backup"
        # TODO: check if backup is already created
        @perform_backup = true
        # Extended configuration for Cost-Optimized scenario
        @additional_instance = false
        @np_system_id = "QAS"
        @np_instance = "10"
        @hook_script_parameters = {}
        @production_constraints = {}
        @hook_script = ""
      end

      def additional_instance=(value)
        @additional_instance = value
        return unless value
        @hook_script_parameters = {
          generated:            false,
          hook_execution_order: "1",
          hook_db_user_name:    "SYSTEM",
          hook_db_password:     "",
          hook_port_number:     "3" + @np_instance + "15",
          hook_db_instance:     @np_instance
        }
        @production_constraints = {
          global_alloc_limit:    65_536.to_s,
          preload_column_tables: "false"
        }
      end

      def np_instance=(value)
        @np_instance = value
        unless @hook_script_parameters[:generated]
          @hook_script_parameters[:hook_db_instance] = @np_instance
          @hook_script_parameters[:hook_port_number] = "3" + @np_instance + "15"
        end
      end

      def configured?
        validate(:silent)
      end

      def validate(verbosity = :verbose)
        SemanticChecks.instance.check(verbosity) do |check|
          check.ipv4(@virtual_ip, "Virtual IP")
          check.nonneg_integer(@virtual_ip_mask, "Virtual IP mask")
          check.integer_in_range(@virtual_ip_mask, 1, 32, "CIDR mask has to be between 1 and 32.",
            "Virtual IP mask")
          check.sap_instance_number(@instance, nil, "Instance Number")
          check.sap_sid(@system_id, nil, "System ID")
          check.element_in_set(@replication_mode, HANA_REPLICATION_MODES,
            "Value should be one of the following: #{HANA_REPLICATION_MODES.join(",")}.",
            "Replication mode")
          if @operation_mode == "logreplay"
            # Logreplay is only available for SPS11+
            version = SapHA::System::Hana.version(@system_id)
            # TODO: remove debug
            flag = SapHA::Helpers.version_comparison("1.00.110", version, ">=")
            check.report_error(flag,
              "Operation mode 'logreplay' is only available for HANA SPS11+"\
              " (detected version #{version || "Unknown"}).", "Operation mode", @operation_mode)
          end
          check.identifier(@site_name_1, nil, "Site name 1")
          check.identifier(@site_name_2, nil, "Site name 2")
          check.element_in_set(@prefer_takeover, [true, false],
            nil, "Prefer site takeover")
          check.element_in_set(@auto_register, [true, false],
            nil, "Automatic registration")
          check.element_in_set(@perform_backup, [true, false],
            nil, "Perform backup")
          # Backup settings should be only validated on the master node
          if @perform_backup && @global_config.role == :master
            check.identifier(@backup_file, nil, "Backup settings/Backup file name")
            check.identifier(@backup_user, nil, "Backup settings/Secure store key")
            keys = SapHA::System::Hana.check_secure_store(@system_id).map(&:downcase)
            check.element_in_set(@backup_user.downcase, keys,
              "There is no such HANA user store key detected.", "Secure store key")
          end
          if @additional_instance
            check.sap_instance_number(@np_instance, nil, "Non-Production Instance Number")
            check.sap_sid(@np_system_id, nil, "Non-Production System ID")
            check.not_equal(@instance, @np_instance, "SAP HANA instance numbers should not collide",
              "Instance number")
            check.not_equal(@system_id, @np_system_id, "SAP HANA System IDs should not collide",
              "System ID")
            hook_script_validation(check, @hook_script_parameters)
            production_constraints_validation(check, @production_constraints)
            check.non_empty_string(@hook_script, "The failover hook script was not generated.",
              "", true)
          end
        end
      end

      def description
        prepare_description do |dsc|
          dsc.header("Production instance") if @additional_instance
          dsc.parameter("System ID", @system_id)
          dsc.parameter("Instance", @instance)
          dsc.parameter("Replication mode", @replication_mode)
          dsc.parameter("Operation mode", @operation_mode)
          dsc.parameter("Virtual IP", @virtual_ip + "/" + @virtual_ip_mask)
          dsc.parameter("Prefer takeover", @prefer_takeover)
          dsc.parameter("Automatic registration", @auto_register)
          dsc.parameter("Site 1 name", @site_name_1)
          dsc.parameter("Site 2 name", @site_name_2)
          dsc.parameter("Perform backup", @perform_backup)
          if @perform_backup
            dsc.parameter("Secure store key", @backup_user)
            dsc.parameter("Backup file", @backup_file)
          end
          if @additional_instance
            dsc.header("Non-production instance")
            dsc.parameter("System ID", @np_system_id)
            dsc.parameter("Instance", @np_instance)
            dsc.header("Production system constraints")
            dsc.parameter("Global allocation limit (MB)",
              @production_constraints[:global_alloc_limit])
            dsc.parameter("Column tables preload",
              @production_constraints[:preload_column_tables])
          end
        end
      end

      def hook_generated?
        @hook_script_parameters[:generated]
      end

      def hook_script_parameters=(value)
        @hook_script_parameters.merge!(value)
        @hook_script = SapHA::Helpers.render_template("tmpl_srhook.py.erb", binding)
        @hook_script_parameters[:generated] = true
      end

      # Validator for the backup settings popup
      # @param check [SapHA::SemanticCheck]
      # @param hash [Hash] input fields' contents
      def hana_backup_validator(check, hash)
        check.identifier(hash[:backup_file], nil, "Backup file name")
        check.identifier(hash[:backup_user], nil, "Secure store key")
        keys = SapHA::System::Hana.check_secure_store(@system_id).map(&:downcase)
        check.element_in_set(hash[:backup_user].downcase, keys,
          "There is no such HANA user store key detected.", "Secure store key")
      end

      # Validator for the hook script settings popup
      # @param check [SapHA::SemanticCheck]
      # @param hash [Hash] input fields' contents
      def hook_script_validation(check, hash)
        check.nonneg_integer(hash[:hook_execution_order], "Hook execution order")
        check.identifier(hash[:hook_db_user_name], nil, "DB user name")
        check.port(hash[:hook_port_number], "Port number")
      end

      # Validator for the production instance constraints popup
      # @param check [SapHA::SemanticCheck]
      # @param hash [Hash] input fields' contents
      def production_constraints_validation(check, hash)
        check.element_in_set(hash[:preload_column_tables], ["true", "false"],
          "The field must contain a boolean value: 'true' or 'false'", "Preload column tables")
        check.nonneg_integer(hash[:global_alloc_limit], "Global allocation limit")
      end

      # Validator for the non-production instance constraints popup
      # @param check [SapHA::SemanticCheck]
      # @param hash [Hash] input fields' contents
      def non_production_constraints_validation(check, hash)
        check.element_in_set(hash[:preload_column_tables], ["true", "false"],
          "The field must contain a boolean value: 'true' or 'false'", "Preload column tables")
        check.nonneg_integer(hash[:global_alloc_limit], "Global allocation limit")
      end

      def apply(role)
        return false unless configured?
        @nlog.info("Appying HANA Configuration")
        config_firewall(@instance,role)
        if role == :master
          SapHA::System::Hana.hdb_start(@system_id)
          if @perform_backup
            secondary_host_name = @global_config.cluster.other_nodes_ext.first[:hostname]
            SapHA::System::Hana.make_backup(@system_id, @backup_user, @backup_file, @instance)
            secondary_password = @global_config.cluster.host_passwords[secondary_host_name]
            SapHA::System::Hana.copy_ssfs_keys(@system_id, secondary_host_name, secondary_password)
          end
          SapHA::System::Hana.enable_primary(@system_id, @site_name_1)
          configure_crm
        else # secondary node
          SapHA::System::Hana.hdb_stop(@system_id)
          primary_host_name = @global_config.cluster.other_nodes_ext.first[:hostname]
          SapHA::System::Hana.enable_secondary(@system_id, @site_name_2,
            primary_host_name, @instance, @replication_mode, @operation_mode)
          if @additional_instance # cost-optimized scenario
            SapHA::System::Hana.hdb_stop(@np_system_id)
            SapHA::System::Hana.adjust_production_system(@system_id,
              @hook_script_parameters.merge(@production_constraints))
            # SapHA::System::Hana.adjust_non_production_system(@np_system_id)
          end
          SapHA::System::Hana.hdb_start(@system_id)
          cleanup_hana_resources
        end
        true
      end

      def cleanup_hana_resources
        # @FIXME: Workaround for Azure-specific issue that needs investigation
        # https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability
        if @global_config.platform == "azure"
          rsc = "rsc_SAPHana_#{@system_id}_HDB#{@instance}"
          cleanup_status = exec_status("crm", "resource", "cleanup", rsc)
          @nlog.log_status(cleanup_status.exitstatus == 0,
            "Performed resource cleanup for #{rsc}",
            "Could not clean up #{rsc}")
        end
      end

      def configure_crm
        # TODO: move this to SapHA::System::Local.configure_crm
        primary_host_name = @global_config.cluster.other_nodes_ext.first[:hostname]
        crm_conf = Helpers.render_template("tmpl_cluster_config.erb", binding)
        file_path = Helpers.write_var_file("cluster.config", crm_conf)
        out, status = exec_outerr_status("crm", "configure", "load", "update", file_path)
        @nlog.log_status(status.exitstatus == 0,
          "Configured necessary cluster resources for HANA System Replication",
          "Could not configure HANA cluster resources", out)
      end

      def config_firewall(instance,role)
        case @global_config.cluster.fw_config
        when "done"
          @nlog.info("Firewall is already configured")
        when "off"
          @nlog.info("Firewall will be turned off")
          SapHA::System::Local.systemd_unit(:stop, :service, "firewalld")
        when "setup"
          @nlog.info("Firewall will be configured for HANA services.")
          instances = Yast::SCR.Read(Yast::Path.new(".sysconfig.hana-firewall.HANA_INSTANCE_NUMBERS")).split
          instances << instance
          Yast::SCR.Write(Yast::Path.new(".sysconfig.hana-firewall.HANA_INSTANCE_NUMBERS"), instances)
          Yast::SCR.Write(Yast::Path.new(".sysconfig.hana-firewall"), nil)
          _s = exec_status("/usr/sbin/hana-firewall", "generate-firewalld-services")
          _s = exec_status("/usr/bin/firewall-cmd", "--reload")
          if role != :master
             _s = exec_status("/usr/bin/firewall-cmd", "--add-port", "8080/tcp")
          end
          HANA_FW_SERVICES.each do |service|
            _s = exec_status("/usr/bin/firewall-cmd", "--add-service", service)
            _s = exec_status("/usr/bin/firewall-cmd", "--permanent", "--add-service", service)
          end
        else
           @nlog.info("Invalide firewall configuration status")
        end
      end
    end
  end
end
