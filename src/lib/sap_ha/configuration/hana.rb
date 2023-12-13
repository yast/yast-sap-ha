# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2023 SUSE Linux GmbH, Nuernberg, Germany.
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
        @perform_backup = true
        # Extended configuration for Cost-Optimized scenario
        @additional_instance = false
        @np_system_id = "QAS"
        @np_instance = "10"
        @production_constraints = {}
      end

      def additional_instance=(value)
        @additional_instance = value
        return unless value
        @prefer_takeover = false
        @production_constraints = {
          global_alloc_limit_prod:  "0",
          global_alloc_limit_non:   "0",
          preload_column_tables: "false"
        }
      end

      def np_instance=(value)
        @np_instance = value
      end

      def configured?
        validate(:silent)
      end

      def validate(verbosity = :verbose)
        SemanticChecks.instance.check(verbosity) do |check|
          check.hana_is_installed(@system_id, @global_config.cluster.all_nodes)
          check.ipv4(@virtual_ip, "Virtual IP")
          check.nonneg_integer(@virtual_ip_mask, "Virtual IP mask")
          check.integer_in_range(@virtual_ip_mask, 1, 32, "CIDR mask has to be between 1 and 32.",
            "Virtual IP mask")
          check.sap_instance_number(@instance, nil, "Instance Number")
          check.sap_sid(@system_id, nil, "System ID")
          check.element_in_set(@replication_mode, HANA_REPLICATION_MODES,
            "Value should be one of the following: #{HANA_REPLICATION_MODES.join(",")}.",
            "Replication mode")
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
            check.hana_is_installed(@np_system_id,@global_config.cluster.other_nodes)
            check.sap_instance_number(@np_instance, nil, "Non-Production Instance Number")
            check.sap_sid(@np_system_id, nil, "Non-Production System ID")
            check.not_equal(@instance, @np_instance, "SAP HANA instance numbers should not collide",
              "Instance number")
            check.not_equal(@system_id, @np_system_id, "SAP HANA System IDs should not collide",
              "System ID")
            production_constraints_validation(check, @production_constraints)
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

      # Validator for the production instance constraints popup
      # @param check [SapHA::SemanticCheck]
      # @param hash [Hash] input fields' contents
      def production_constraints_validation(check, hash)
        check.element_in_set(hash[:preload_column_tables], ["true", "false"],
          "The field must contain a boolean value: 'true' or 'false'", "Preload column tables")
        check.not_equal(hash[:global_alloc_limit_prod], 0.to_s, "Global allocation limit production system must be adapted.")
        check.not_equal(hash[:global_alloc_limit_non], 0.to_s, "Global allocation limit of non production system must be adapted.")
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
        @nlog.info("Applying HANA Configuration")
        configure_firewall(role)
        if role == :master
          if @perform_backup
            SapHA::System::Hana.make_backup(@system_id, @backup_user, @backup_file, @instance)
          end
          secondary_host_name = @global_config.cluster.other_nodes_ext.first[:hostname]
          secondary_password = @global_config.cluster.host_passwords[secondary_host_name]
          SapHA::System::Hana.copy_ssfs_keys(@system_id, secondary_host_name, secondary_password)
          SapHA::System::Hana.enable_primary(@system_id, @site_name_1)
        else # secondary node
          SapHA::System::Hana.hdb_stop(@system_id)
          primary_host_name = @global_config.cluster.other_nodes_ext.first[:hostname]
          SapHA::System::Hana.enable_secondary(@system_id, @site_name_2,
            primary_host_name, @instance, @replication_mode, @operation_mode)
          cleanup_hana_resources
          SapHA::System::Hana.hdb_start(@system_id)
        end
        adapt_sudoers
        adjust_global_ini(role)
        true
      end

      def finalize
        configure_crm
        wait_idle(@global_config.cluster.get_primary_on_primary)
        activating_msr
      end

    private

      def configure_crm
        primary_host_name = @global_config.cluster.get_primary_on_primary
        secondary_host_name = @global_config.cluster.other_nodes_ext.first[:hostname]
        crm_conf = Helpers.render_template("tmpl_cluster_config.erb", binding)
        file_path = Helpers.write_var_file("cluster.config", crm_conf)
        out, status = exec_outerr_status("crm", "configure", "load", "update", file_path)
        @nlog.log_status(status.exitstatus == 0,
          "Configured necessary cluster resources for HANA System Replication",
          "Could not configure HANA cluster resources", out)
      end

      # Wait until the node is in state S_IDLE but maximal 60 seconds
      def wait_idle(node)
        counter = 0
        while true
          out, status = exec_outerr_status("crmadmin","--quiet","--status",node)
          break if out == "S_IDLE"
          log.info("wait_idle status of #{node} is #{out}")
	  counter += 1
	  break if counter > 10
          sleep 6
        end
      end

      def activating_msr
        msr = "msl_SAPHana_#{@system_id}_HDB#{@instance}"
        out, status = exec_outerr_status("crm", "resource", "refresh", msr)
        @nlog.log_status(status.exitstatus == 0,
          "#{msr} status refresh OK",
          "Could not refresh status of #{msr}: #{out}")
        out, status = exec_outerr_status("crm", "resource", "maintenance", msr, "off")
        @nlog.log_status(status.exitstatus == 0,
          "#{msr} maintenance turned off.",
          "Could turn off maintenance on #{msr}: #{out}")
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

      # Adapt the firewall depending on the @global_config.cluster.fw_config
      # Even if the firewall is already configured the TCP port 8080 will be opened for internal RPC communication during setup
      # If the firewall should be stoped during cofiguration no other action is necessary
      # If the firewall should be configured in the first step the HANA-Services will be generated by hana-firewall.
      # After them the generated services and the service cluster will be added to the default zone.
      def configure_firewall(role)
        case @global_config.cluster.fw_config
        when "done"
          @nlog.info("Firewall is already configured")
          if role != :master
             _s = exec_status("/usr/bin/firewall-cmd", "--add-port", "8080/tcp")
          end
        when "off"
          @nlog.info("Firewall will be turned off")
          SapHA::System::Local.systemd_unit(:stop, :service, "firewalld")
        when "setup"
          @nlog.info("Firewall will be configured for HANA services.")
          instances = Yast::SCR.Read(Yast::Path.new(".sysconfig.hana-firewall.HANA_INSTANCE_NUMBERS")).split
          instances << @instance
          Yast::SCR.Write(Yast::Path.new(".sysconfig.hana-firewall.HANA_INSTANCE_NUMBERS"), instances.join(" "))
          Yast::SCR.Write(Yast::Path.new(".sysconfig.hana-firewall"), nil)
          _s = exec_status("/usr/sbin/hana-firewall", "generate-firewalld-services")
          _s = exec_status("/usr/bin/firewall-cmd", "--reload")
          if role != :master
             _s = exec_status("/usr/bin/firewall-cmd", "--add-port", "8080/tcp")
          end
          _s = exec_status("/usr/bin/firewall-cmd", "--add-service", "cluster")
          _s = exec_status("/usr/bin/firewall-cmd", "--permanent", "--add-service", "cluster")
          HANA_FW_SERVICES.each do |service|
            _s = exec_status("/usr/bin/firewall-cmd", "--add-service", service)
            _s = exec_status("/usr/bin/firewall-cmd", "--permanent", "--add-service", service)
          end
        else
           @nlog.info("Invalide firewall configuration status")
        end
      end

      # Creates the sudoers file
      def adapt_sudoers
        if File.exist?(SapHA::Helpers.data_file_path("SUDOERS_HANASR.erb"))
          Helpers.write_file("/etc/sudoers.d/saphanasr.conf",Helpers.render_template("SUDOERS_HANASR.erb", binding))
        end
      end

      # Activates all necessary plugins based on role an scenario
      def adjust_global_ini(role)
        # SAPHanaSR is needed on all nodes
        add_plugin_to_global_ini("SAPHANA_SR", @system_id)
        if @additional_instance
          # cost optimized
          add_plugin_to_global_ini("SUS_COSTOPT", @system_id) if role != :master
          add_plugin_to_global_ini("NON_PROD", @np_system_id) if role != :master
          command = ["hdbnsutil", "-reloadHADRProviders"]
          _out, _status = su_exec_outerr_status("#{@np_system_id.downcase}adm", *command)
        else
          # performance optimized
          add_plugin_to_global_ini("SUS_CHKSRV", @system_id)
          add_plugin_to_global_ini("SUS_TKOVER", @system_id)
        end
        command = ["hdbnsutil", "-reloadHADRProviders"]
        _out, _status = su_exec_outerr_status("#{@system_id.downcase}adm", *command)
      end

      # Activates the plugin in global ini
      def add_plugin_to_global_ini(plugin, sid)
        sr_path = Helpers.data_file_path("GLOBAL_INI_#{plugin}")
        if File.exist?("#{sr_path}.erb")
          sr_path = Helpers.write_var_file(plugin, Helpers.render_template("GLOBAL_INI_#{plugin}.erb", binding))
        end
        command = ["/usr/sbin/SAPHanaSR-manageProvider", "--add", "--reconfigure", "--sid", sid, sr_path]
        _out, _status = su_exec_outerr_status("#{sid.downcase}adm", *command)
      end
    end
  end
end
